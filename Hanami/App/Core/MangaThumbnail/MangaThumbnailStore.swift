//
//  ThumbnailFeature.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct MangaThumbnailState: Equatable, Identifiable {
    init(manga: Manga, isOnline: Bool = true) {
        self.manga = manga
        self.isOnline = isOnline
        
        if isOnline {
            onlineMangaState = OnlineMangaViewState(manga: manga)
        } else {
            offlineMangaState = OfflineMangaViewState(manga: manga)
        }
        // in some cases we can have coverArt included with manga as relationship
        if let coverArtInfo = manga.coverArtInfo {
            self.coverArtInfo = coverArtInfo
            
            if isOnline {
                onlineMangaState!.mainCoverArtURL = coverArtInfo.coverArtURL
                onlineMangaState!.coverArtURL256 = coverArtInfo.coverArtURL256
            }
        }
    }
    
    var onlineMangaState: OnlineMangaViewState?
    var offlineMangaState: OfflineMangaViewState?
    let manga: Manga
    var coverArtInfo: CoverArtInfo?
    
    let isOnline: Bool
    
    var mangaStatistics: MangaStatistics? {
        onlineMangaState?.statistics
    }
    
    var id: UUID { manga.id }
}

enum MangaThumbnailAction {
    case onAppear
    case checkForMangaStatisticsAfterDelay
    case coverArtRetrieved(Result<UIImage, Error>)
    case thumbnailInfoLoaded(Result<Response<CoverArtInfo>, AppError>)
    case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
    case userOpenedMangaView
    case userLeftMangaView
    case userLeftMangaViewDelayCompleted
    case onlineMangaAction(OnlineMangaViewAction)
    case offlineMangaAction(OfflineMangaViewAction)
}

struct MangaThumbnailEnvironment {
    let databaseClient: DatabaseClient
    let hapticClient: HapticClient
    let imageClient: ImageClient
    let cacheClient: CacheClient
    let mangaClient: MangaClient
    let hudClient: HUDClient
}

let mangaThumbnailReducer = Reducer.combine(
    onlineMangaThumbnailReducer,
    offlineMangaThumbnailReducer
)


// swiftlint:disable:next line_length
let offlineMangaThumbnailReducer: Reducer<MangaThumbnailState, MangaThumbnailAction, MangaThumbnailEnvironment>  = .combine(
    offlineMangaViewReducer.optional().pullback(
        state: \.offlineMangaState,
        action: /MangaThumbnailAction.offlineMangaAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            hapticClient: $0.hapticClient,
            cacheClient: $0.cacheClient,
            imageClient: $0.imageClient,
            mangaClient: $0.mangaClient,
            hudClient: $0.hudClient
        ) }
    ),
    Reducer { state, action, env in
        guard !state.isOnline else {
            return .none
        }
        
        switch action {
            case .onAppear:
                guard state.offlineMangaState!.coverArt == nil else {
                    return .none
                }
                
                return env.mangaClient.retrieveCoverArt(state.manga.id, env.cacheClient)
                    .receive(on: DispatchQueue.main)
                    .eraseToEffect(MangaThumbnailAction.coverArtRetrieved)
                
            case .coverArtRetrieved(let result):
                switch result {
                    case .success(let coverArt):
                        state.offlineMangaState!.coverArt = coverArt
                        
                        return .none
                        
                    case .failure(let error):
                        print("error on retrieving coverArt: \(error)")
                        return .none
                }
                
            default:
                return .none
        }
    }
)

// swiftlint:disable:next line_length
let onlineMangaThumbnailReducer: Reducer<MangaThumbnailState, MangaThumbnailAction, MangaThumbnailEnvironment> = .combine(
    onlineMangaViewReducer.optional().pullback(
        state: \.onlineMangaState,
        action: /MangaThumbnailAction.onlineMangaAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            hapticClient: $0.hapticClient,
            cacheClient: $0.cacheClient,
            imageClient: $0.imageClient,
            mangaClient: $0.mangaClient,
            hudClient: $0.hudClient
        ) }
    ),
    Reducer { state, action, env in
        guard state.isOnline else {
            return .none
        }
        
        switch action {
            case .onAppear:
                var effects: [Effect<MangaThumbnailAction, Never>] = []
                if state.coverArtInfo == nil,
                   let coverArtID = state.manga.relationships.first(where: { $0.type == .coverArt })?.id {
                    effects.append(
                        env.mangaClient.fetchCoverArtInfo(coverArtID)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(MangaThumbnailAction.thumbnailInfoLoaded)
                   )
                }
                
                effects.append(
                    Effect(value: MangaThumbnailAction.checkForMangaStatisticsAfterDelay)
                        .delay(for: .seconds(5), scheduler: DispatchQueue.main)
                        .eraseToEffect()
                )
                
                return .merge(effects)
                
            case .checkForMangaStatisticsAfterDelay:
                if state.mangaStatistics == nil {
                    return env.mangaClient.fetchMangaStatistics(state.manga.id)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(MangaThumbnailAction.mangaStatisticsFetched)
                }
                
                return .none
                
            case .mangaStatisticsFetched(let result):
                switch result {
                    case .success(let response):
                        state.onlineMangaState!.statistics = response.statistics[state.manga.id]
                        
                        return .none
                        
                    case .failure(let error):
                        print("error on downloading thumbnail info: \(error)")
                        return .none
                }
                
            case .thumbnailInfoLoaded(let result):
                switch result {
                    case .success(let response):
                        state.coverArtInfo = response.data
                        state.onlineMangaState!.mainCoverArtURL = state.coverArtInfo!.coverArtURL
                        state.onlineMangaState!.coverArtURL256 = state.coverArtInfo!.coverArtURL256
                        return .none
                        
                    case .failure(let error):
                        print("error on downloading thumbnail info: \(error)")
                        return .none
                }
                
            case .userOpenedMangaView:
                // when users enters the view, we must cancel clearing manga info
                return .cancel(id: OnlineMangaViewState.CancelClearCache(mangaID: state.manga.id))
                
            case .userLeftMangaView:
                // Runs a delay(60 sec.) when user leaves MangaView, after that all downloaded data will be deleted to save RAM
                // Can be cancelled if user returns wihing 60 sec.
                return .task {
                    let sixtySeconds: UInt64 = 1_000_000_000 * 60
                    try await Task.sleep(nanoseconds: sixtySeconds)
                    
                    return MangaThumbnailAction.userLeftMangaViewDelayCompleted
                }
                .eraseToEffect()
                .cancellable(id: OnlineMangaViewState.CancelClearCache(mangaID: state.manga.id))

            case .userLeftMangaViewDelayCompleted:
                state.onlineMangaState!.reset()
                return .none
                
            case .onlineMangaAction:
                return .none
                
            case .coverArtRetrieved:
                return .none
                
            case .offlineMangaAction:
                return .none
        }
    }
)
