//
//  DownloadsStore.swift
//  Hanami
//
//  Created by Oleg on 19/07/2022.
//

import Foundation
import ComposableArchitecture


struct DownloadsState: Equatable {
    var cachedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
}

enum DownloadsAction {
    case retrieveCachedManga
    case cachedMangaFetched(Result<[Manga], Never>)
    case cachedMangaThumbnailAction(id: UUID, action: MangaThumbnailAction)
}

struct DownloadsEnvironment {
    let databaseClient: DatabaseClient
    let hapticClient: HapticClient
    let cacheClient: CacheClient
    let imageClient: ImageClient
    let mangaClient: MangaClient
    let hudClient: HUDClient
}

let downloadsReducer: Reducer<DownloadsState, DownloadsAction, DownloadsEnvironment> = .combine(
    mangaThumbnailReducer
        .forEach(
            state: \.cachedMangaThumbnailStates,
            action: /DownloadsAction.cachedMangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    hapticClient: $0.hapticClient,
                    imageClient: $0.imageClient,
                    cacheClient: $0.cacheClient,
                    mangaClient: $0.mangaClient,
                    hudClient: $0.hudClient
                )
            }
        ),
    Reducer { state, action, env in
        switch action {
            case .retrieveCachedManga:
                return env.databaseClient.fetchAllCachedMangas()
                    .catchToEffect(DownloadsAction.cachedMangaFetched)
                
            case .cachedMangaFetched(let result):
                switch result {
                    case .success(let retrievedMangas):
                        let cachedMangaIDsSet = Set(state.cachedMangaThumbnailStates.map(\.id))
                        let retrievedMangaIDs = Set(retrievedMangas.map(\.id))
                        let stateIDsToLeave = cachedMangaIDsSet.intersection(retrievedMangaIDs)
                        let newMangaIDs = retrievedMangaIDs.subtracting(stateIDsToLeave)
                        
                        state.cachedMangaThumbnailStates.removeAll(where: { !stateIDsToLeave.contains($0.id) })
                        
                        for manga in retrievedMangas where newMangaIDs.contains(manga.id) {
                            state.cachedMangaThumbnailStates.append(
                                MangaThumbnailState(manga: manga, online: false)
                            )
                        }
                        
                        return .none
                        
                    case .failure:
                        return .none
                }
                
            case .cachedMangaThumbnailAction(_, .offlineMangaAction(.deleteManga)):
                return .task { .retrieveCachedManga }
                    .delay(for: .seconds(0.2), scheduler: DispatchQueue.main)
                    .eraseToEffect()
                
            case .cachedMangaThumbnailAction(_, .userLeftMangaView):
                return .task { .retrieveCachedManga }
                    .delay(for: .seconds(0.2), scheduler: DispatchQueue.main)
                    .eraseToEffect()
                

            case .cachedMangaThumbnailAction:
                return .none
        }
    }
)
