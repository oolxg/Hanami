//
//  ThumbnailFeature.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation
import ComposableArchitecture
import ModelKit
import Utils
import Logger

struct MangaThumbnailFeature: Reducer {
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
        var isMangaViewPresented = false
        var id: UUID { manga.id }
    }
    
    enum Action {
        case onAppear
        case thumbnailInfoLoaded(Result<Response<CoverArtInfo>, AppError>)
        case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
        case onlineMangaAction(OnlineMangaFeature.Action)
        case offlineMangaAction(OfflineMangaFeature.Action)
        case navLinkValueDidChange(to: Bool)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.thumbnailURL.isNil else { return .none }
                
                if state.online, let coverArtID = state.manga.coverArtID {
                    return mangaClient
                        .fetchCoverArtInfo(coverArtID)
                        .catchToEffect(Action.thumbnailInfoLoaded)
                } else {
                    state.offlineMangaState!.coverArtPath = mangaClient.getCoverArtPath(
                        state.manga.id, cacheClient
                    )
                    
                    return .none
                }
                
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
                state.isMangaViewPresented = false
                return .none
                
            case .navLinkValueDidChange(let newValue):
                state.isMangaViewPresented = newValue
                return .none
                
            case .onlineMangaAction:
                return .none
                
            case .offlineMangaAction:
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
