//
//  DownloadsStore.swift
//  Smuggler
//
//  Created by mk.pwnz on 19/07/2022.
//

import Foundation
import ComposableArchitecture


struct DownloadsState: Equatable {
    var cachedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
}

enum DownloadsAction {
    case fetchCachedManga
    
    case cachedMangaFetched(Result<[Manga], Never>)
    
    case cachedMangaThumbnailAction(id: UUID, action: MangaThumbnailAction)
}

struct DownloadsEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
    let cacheClient: CacheClient
    let imageClient: ImageClient
    let hudClient: HUDClient
    let hapticClient: HapticClient
}

let downloadsReducer: Reducer<DownloadsState, DownloadsAction, DownloadsEnvironment> = .combine(
    mangaThumbnailReducer
        .forEach(
            state: \.cachedMangaThumbnailStates,
            action: /DownloadsAction.cachedMangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient,
                    cacheClient: $0.cacheClient,
                    imageClient: $0.imageClient,
                    hudClient: $0.hudClient,
                    hapticClient: $0.hapticClient
                )
            }
        ),
    Reducer { state, action, env in
        switch action {
            case .fetchCachedManga:
                return env.databaseClient.fetchAllCachedMangas()
                    .catchToEffect(DownloadsAction.cachedMangaFetched)
                
            case .cachedMangaFetched(let result):
                switch result {
                    case .success(let retrievedMangas):
                        let chapterStateIDsSet = Set(state.cachedMangaThumbnailStates.map(\.id))
                        let mangaIDs = Set(retrievedMangas.map(\.id))
                        let stateIDsToLeave = chapterStateIDsSet.intersection(mangaIDs)
                        let newMangaIDs = mangaIDs.subtracting(stateIDsToLeave)
                        
                        state.cachedMangaThumbnailStates.removeAll(where: { !stateIDsToLeave.contains($0.id) })
                        
                        for manga in retrievedMangas {
                            if newMangaIDs.contains(manga.id) {
                                state.cachedMangaThumbnailStates.append(
                                    MangaThumbnailState(manga: manga, isOnline: false)
                                )
                            }
                        }
                        
                        return .none
                        
                    case .failure:
                        return .none
                }
                
            case .cachedMangaThumbnailAction(_, .offlineMangaAction(.deleteManga)):
                return Effect(value: .fetchCachedManga)
                    .delay(for: .seconds(0.2), scheduler: DispatchQueue.main)
                    .eraseToEffect()
                
            case .cachedMangaThumbnailAction:
                return .none
        }
    }
)
