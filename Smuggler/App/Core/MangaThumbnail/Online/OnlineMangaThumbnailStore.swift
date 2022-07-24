//
//  ThumbnailFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct OnlineMangaThumbnailState: Equatable, Identifiable {
    init(manga: Manga) {
        self.manga = manga
        self.mangaState = OnlineMangaViewState(manga: manga)
    }
    
    var mangaState: OnlineMangaViewState
    let manga: Manga
    var coverArtInfo: CoverArtInfo?
    
    var mangaStatistics: MangaStatistics? {
        mangaState.statistics
    }
    
    var id: UUID { manga.id }
}

enum OnlineMangaThumbnailAction {
    case onAppear
    case thumbnailInfoLoaded(Result<Response<CoverArtInfo>, AppError>)
    case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
    case userOpenedMangaView
    case userLeftMangaView
    case userLeftMangaViewDelayCompleted
    case mangaAction(OnlineMangaViewAction)
}

struct MangaThumbnailEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
    let cacheClient: CacheClient
}

// swiftlint:disable:next line_length
let onlineMangaThumbnailReducer = Reducer<OnlineMangaThumbnailState, OnlineMangaThumbnailAction, MangaThumbnailEnvironment>.combine(
    onlineMangaViewReducer.pullback(
        state: \.mangaState,
        action: /OnlineMangaThumbnailAction.mangaAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            mangaClient: $0.mangaClient
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                // if we already loaded info about cover, we don't need to do it one more time
                guard state.coverArtInfo == nil else { return .none }
                
                // in some cases we can have coverArt included with manga as relationship
                if let coverArtInfo = state.manga.relationships
                        .first(where: { $0.attributes != nil && $0.type == .coverArt }),
                   let coverArtAttr = coverArtInfo.attributes!.get() as? CoverArtInfo.Attributes {
                    state.coverArtInfo = CoverArtInfo(
                        id: UUID(), type: .coverArt, attributes: coverArtAttr, relationships: [
                            .init(id: state.manga.id, type: .manga)
                        ]
                    )
                    
                    state.mangaState.mainCoverArtURL = state.coverArtInfo!.coverArtURL
                    state.mangaState.coverArtURL512 = state.coverArtInfo!.coverArtURL512
                }
                
                var effects: [Effect<OnlineMangaThumbnailAction, Never>] = []
                
                if state.coverArtInfo == nil,
                   let coverArtID = state.manga.relationships.first(where: { $0.type == .coverArt })?.id {
                    effects.append(
                        env.mangaClient.fetchCoverArtInfo(coverArtID)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(OnlineMangaThumbnailAction.thumbnailInfoLoaded)
                    )
                }
                
                if state.mangaStatistics == nil {
                    effects.append(
                        env.mangaClient.fetchMangaStatistics(state.manga.id)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(OnlineMangaThumbnailAction.mangaStatisticsFetched)
                    )
                }
                
                return .merge(effects)
                
            case .mangaStatisticsFetched(let result):
                switch result {
                    case .success(let response):
                        state.mangaState.statistics = response.statistics[state.manga.id]

                        return .none
                        
                    case .failure(let error):
                        print("error on downloading thumbnail info: \(error)")
                        return .none
                }
                
            case .thumbnailInfoLoaded(let result):
                switch result {
                    case .success(let response):
                        CacheClient.live.cacheCoverArtInfo(response.data)
                        state.coverArtInfo = response.data
                        state.mangaState.mainCoverArtURL = state.coverArtInfo?.coverArtURL
                        state.mangaState.coverArtURL512 = state.coverArtInfo?.coverArtURL512
                        return .none
                        
                    case .failure(let error):
                        print("error on downloading thumbnail info: \(error)")
                        return .none
                }
                
            case .userOpenedMangaView:
                // when users enters the view, we must cancel clearing manga info
                return .cancel(id: OnlineMangaViewState.CancelClearCacheForManga(mangaID: state.manga.id))
                
            case .userLeftMangaView:
                // Runs a delay(60 sec.) when user leaves MangaView, after that all downloaded data will be deleted to save RAM
                // Can be cancelled if user returns wihing 60 sec.
                return Effect(value: OnlineMangaThumbnailAction.userLeftMangaViewDelayCompleted)
                    .delay(for: .seconds(60), scheduler: DispatchQueue.main)
                    .eraseToEffect()
                    .cancellable(id: OnlineMangaViewState.CancelClearCacheForManga(mangaID: state.manga.id))
                
            case .userLeftMangaViewDelayCompleted:
                state.mangaState.reset()
                return .none
                
            case .mangaAction:
                return .none
        }
    }
)
