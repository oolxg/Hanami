//
//  ThumbnailFeature.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation
import ComposableArchitecture

struct MangaThumbnailFeature: ReducerProtocol {
    struct State: Equatable, Identifiable {
        init(manga: Manga, online: Bool = true) {
            if online {
                onlineMangaState = OnlineMangaFeature.State(manga: manga)
                
                // in some cases we can have coverArt included with manga as relationship
                if let coverArtInfo = manga.coverArtInfo {
                    onlineMangaState!.mainCoverArtURL = coverArtInfo.coverArtURL
                    onlineMangaState!.coverArtURL256 = coverArtInfo.coverArtURL256
                }
            } else {
                offlineMangaState = OfflineMangaFeature.State(manga: manga)
            }
        }
        
        var onlineMangaState: OnlineMangaFeature.State?
        var offlineMangaState: OfflineMangaFeature.State?
        var manga: Manga {
            online ? onlineMangaState!.manga : offlineMangaState!.manga
        }
        var mangaStatistics: MangaStatistics? {
            onlineMangaState?.statistics
        }
        
        var thumbnailURL: URL? {
            online ? onlineMangaState!.coverArtURL256 : offlineMangaState!.coverArtPath
        }
        
        var online: Bool { onlineMangaState.hasValue }
        @BindableState var navigationLinkActive = false
        var id: UUID { manga.id }
    }
    
    enum Action: BindableAction {
        case onAppear
        case thumbnailInfoLoaded(Result<Response<CoverArtInfo>, AppError>)
        case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
        case userLeftMangaView
        case userLeftMangaViewDelayCompleted
        case onlineMangaAction(OnlineMangaFeature.Action)
        case offlineMangaAction(OfflineMangaFeature.Action)
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.online, state.onlineMangaState!.coverArtURL256.isNil, let coverArtID = state.manga.coverArtID {
                    return mangaClient
                        .fetchCoverArtInfo(coverArtID)
                        .catchToEffect(Action.thumbnailInfoLoaded)
                } else if !state.online {
                    guard state.offlineMangaState!.coverArtPath.isNil else {
                        return .none
                    }
                    
                    state.offlineMangaState!.coverArtPath = mangaClient.getCoverArtPath(
                        state.manga.id, cacheClient
                    )
                }
                
                return .none
                
            case .mangaStatisticsFetched(let result):
                switch result {
                case .success(let response):
                    state.onlineMangaState!.statistics = response.statistics[state.manga.id]
                    
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to load manga statistics: \(error)",
                        context: [
                            "mangaID": "\(state.manga.id.uuidString.lowercased())",
                            "mangaName": "\(state.manga.title)"
                        ]
                    )
                    return .none
                }
                
            case .thumbnailInfoLoaded(let result):
                switch result {
                case .success(let response):
                    state.onlineMangaState!.mainCoverArtURL = response.data.coverArtURL
                    state.onlineMangaState!.coverArtURL256 = response.data.coverArtURL256
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to load thumbnail info: \(error)",
                        context: [
                            "mangaID": "\(state.manga.id.uuidString.lowercased())",
                            "mangaName": "\(state.manga.title)"
                        ]
                    )
                    return .none
                }
                
            case .offlineMangaAction(.pagesAction(.userDeletedAllCachedChapters)):
                state.navigationLinkActive = false
                return .none
                
            // action only to hijack it in DownloadsFeature
            case .userLeftMangaView:
                return .none
                
            case .userLeftMangaViewDelayCompleted:
                state.onlineMangaState!.reset()
                return .none
                
            case .binding(\.$navigationLinkActive):
                if state.navigationLinkActive {
                    // when users enters the view, we must cancel clearing manga info
                    return .cancel(id: OnlineMangaFeature.CancelClearCache(mangaID: state.manga.id))
                }
                
                // Runs a delay(60 sec.) when user leaves MangaView, after that all downloaded data will be deleted to save RAM
                // Can be cancelled if user returns wihing 60 sec.
                return .merge(
                    .task { .userLeftMangaViewDelayCompleted }
                        .debounce(for: .seconds(60), scheduler: mainQueue)
                        .eraseToEffect()
                        .cancellable(id: OnlineMangaFeature.CancelClearCache(mangaID: state.manga.id)),
                    
                        .task { .userLeftMangaView }
                )
                
            case .onlineMangaAction:
                return .none
                
            case .offlineMangaAction:
                return .none
                
            case .binding:
                return .none
            }
        }
        .ifLet(\.offlineMangaState, action: /Action.offlineMangaAction) {
            OfflineMangaFeature()
        }
        .ifLet(\.onlineMangaState, action: /Action.onlineMangaAction) {
            OnlineMangaFeature()
        }
    }
}
