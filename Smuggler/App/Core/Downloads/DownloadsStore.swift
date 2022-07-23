//
//  DownloadsStore.swift
//  Smuggler
//
//  Created by mk.pwnz on 19/07/2022.
//

import Foundation
import ComposableArchitecture


struct DownloadsState: Equatable {
    var cachedMangaThumbnailStates: IdentifiedArrayOf<OfflineMangaThumbnailState> = []
}

enum DownloadsAction {
    case fetchCachedManga
    
    case cachedMangaFetched(Result<[Manga], Never>)
    
    case cachedMangaThumbnailAction(id: UUID, action: OfflineMangaThumbnailAction)
}

struct DownloadsEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
}

let downloadsReducer: Reducer<DownloadsState, DownloadsAction, DownloadsEnvironment> = .combine(
    offlineMangaThumbnailReducer
        .forEach(
            state: \.cachedMangaThumbnailStates,
            action: /DownloadsAction.cachedMangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient
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
                    case .success(let cachedManga):
                        let chapterStateIDsSet = Set(state.cachedMangaThumbnailStates.map(\.id))
                        let mangaIDs = Set(cachedManga.map(\.id))
                        let stateIDsToLeave = chapterStateIDsSet.intersection(mangaIDs)
                        let newMangaIDs = mangaIDs.subtracting(stateIDsToLeave)
                        
                        state.cachedMangaThumbnailStates.removeAll(where: { !stateIDsToLeave.contains($0.id) })
                        
                        for manga in cachedManga {
                            if newMangaIDs.contains(manga.id) {
                                state.cachedMangaThumbnailStates.append(
                                    OfflineMangaThumbnailState(manga: manga)
                                )
                            }
                        }
                        
                        return .none
                        
                    case .failure:
                        return .none
                }
                
            case .cachedMangaThumbnailAction:
                return .none
        }
    }
)
