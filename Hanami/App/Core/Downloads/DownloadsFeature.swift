//
//  DownloadsStore.swift
//  Hanami
//
//  Created by Oleg on 19/07/2022.
//

import Foundation
import ComposableArchitecture

struct DownloadsFeature: ReducerProtocol {
    struct State: Equatable {
        var cachedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
    }
    
    enum Action {
        case retrieveCachedManga
        case cachedMangaFetched(Result<[Manga], Never>)
        case cachedMangaThumbnailAction(id: UUID, action: MangaThumbnailFeature.Action)
    }
    
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .retrieveCachedManga:
                return databaseClient.fetchAllCachedMangas()
                    .catchToEffect(Action.cachedMangaFetched)
                
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
                            MangaThumbnailFeature.State(manga: manga, online: false)
                        )
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to retrieve all cached manga from disk: \(error)")
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
        .forEach(\.cachedMangaThumbnailStates, action: /Action.cachedMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
    }
}
