//
//  ThumbnailFeature.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation
import ComposableArchitecture

struct MangaThumbnailState: Equatable, Identifiable {
    init(manga: Manga, online: Bool = true) {
        if online {
            onlineMangaState = OnlineMangaViewState(manga: manga)
            
            // in some cases we can have coverArt included with manga as relationship
            if let coverArtInfo = manga.coverArtInfo {
                onlineMangaState!.mainCoverArtURL = coverArtInfo.coverArtURL
                onlineMangaState!.coverArtURL256 = coverArtInfo.coverArtURL256
            }
        } else {
            offlineMangaState = OfflineMangaViewState(manga: manga)
        }
    }
    
    var onlineMangaState: OnlineMangaViewState?
    var offlineMangaState: OfflineMangaViewState?
    var manga: Manga {
        online ? onlineMangaState!.manga : offlineMangaState!.manga
    }
    var mangaStatistics: MangaStatistics? {
        onlineMangaState?.statistics
    }
    
    var thumbnailURL: URL? {
        online ? onlineMangaState!.coverArtURL256 : offlineMangaState!.coverArtPath
    }
    
    var online: Bool { onlineMangaState != nil }
    
    var id: UUID { manga.id }
}

enum MangaThumbnailAction {
    case onAppear
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

let mangaThumbnailReducer: Reducer<MangaThumbnailState, MangaThumbnailAction, MangaThumbnailEnvironment> = .combine(
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
        switch action {
            case .onAppear:
                if state.online, state.onlineMangaState!.coverArtURL256 == nil, let coverArtID = state.manga.coverArtID {
                    return env.mangaClient
                        .fetchCoverArtInfo(coverArtID)
                        .catchToEffect(MangaThumbnailAction.thumbnailInfoLoaded)
                } else if !state.online {
                    guard state.offlineMangaState!.coverArtPath == nil else {
                        return .none
                    }
                    
                    state.offlineMangaState!.coverArtPath = env.mangaClient.getCoverArtPath(
                        state.manga.id, env.cacheClient
                    )
                }
                
                return .none
                
            case .mangaStatisticsFetched(let result):
                switch result {
                    case .success(let response):
                        state.onlineMangaState!.statistics = response.statistics[state.manga.id]
                        
                        return .none
                        
                    case .failure(let error):
                        print("error on downloading thumbnail info: \(error.description)")
                        return .none
                }
                
            case .thumbnailInfoLoaded(let result):
                switch result {
                    case .success(let response):
                        state.onlineMangaState!.mainCoverArtURL = response.data.coverArtURL
                        state.onlineMangaState!.coverArtURL256 = response.data.coverArtURL256
                        return .none
                        
                    case .failure(let error):
                        print("error on downloading thumbnail info: \(error.description)")
                        return .none
                }
                
            case .userOpenedMangaView:
                // when users enters the view, we must cancel clearing manga info
                return .cancel(id: OnlineMangaViewState.CancelClearCache(mangaID: state.manga.id))
                
            case .userLeftMangaView:
                // Runs a delay(60 sec.) when user leaves MangaView, after that all downloaded data will be deleted to save RAM
                // Can be cancelled if user returns wihing 60 sec.
                return .task { MangaThumbnailAction.userLeftMangaViewDelayCompleted }
                    .debounce(for: .seconds(60), scheduler: DispatchQueue.main)
                    .eraseToEffect()
                    .cancellable(id: OnlineMangaViewState.CancelClearCache(mangaID: state.manga.id))

            case .userLeftMangaViewDelayCompleted:
                state.onlineMangaState!.reset()
                return .none
                
            case .onlineMangaAction:
                return .none
                
            case .offlineMangaAction:
                return .none
        }
    }
)
