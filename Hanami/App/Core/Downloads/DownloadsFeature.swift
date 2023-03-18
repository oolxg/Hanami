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
        var mangaEntries: IdentifiedArrayOf<CoreDataMangaEntry> = []
        var currentSortOrder = SortOrder.firstAdded
    }
    
    enum Action {
        case initDownloads
        case cachedMangaFetched(Result<[CoreDataMangaEntry], Never>)
        case cachedMangaThumbnailAction(id: UUID, action: MangaThumbnailFeature.Action)
        case sortOrderChanged(SortOrder)
    }
    
    enum SortOrder: String, CaseIterable {
        case alphabeticallyAsc = "Title Ascending"
        case alphabeticallyDesc = "Title Descending"
        case lastAdded = "Latest Added"
        case firstAdded = "Oldest Added"
    }
    
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .initDownloads:
                return databaseClient
                    .retrieveAllCachedMangas()
                    .catchToEffect(Action.cachedMangaFetched)
                
            case .cachedMangaFetched(let result):
                switch result {
                case .success(let retrievedMangaEntries):
                    let cachedMangaIDsSet = state.cachedMangaThumbnailStates.ids
                    let retrievedMangaIDs = retrievedMangaEntries.ids
                    let stateIDsToLeave = cachedMangaIDsSet.intersection(retrievedMangaIDs)
                    let newMangaIDs = retrievedMangaIDs.subtracting(stateIDsToLeave)
                    
                    state.cachedMangaThumbnailStates.removeAll(where: { !stateIDsToLeave.contains($0.id) })
                    
                    state.mangaEntries = retrievedMangaEntries.asIdentifiedArray
                    
                    for entry in retrievedMangaEntries where newMangaIDs.contains(entry.manga.id) {
                        state.cachedMangaThumbnailStates.append(
                            MangaThumbnailFeature.State(manga: entry.manga, online: false)
                        )
                    }
                    
                    let coverArtPaths = state.cachedMangaThumbnailStates.map(\.thumbnailURL).compactMap { $0 }
                    
                    return imageClient.prefetchImages(coverArtPaths).fireAndForget()
                    
                case .failure(let error):
                    logger.error("Failed to retrieve all cached manga from disk: \(error)")
                    return .none
                }
                
            case .cachedMangaThumbnailAction(_, .offlineMangaAction(.deleteMangaButtonTapped)):
                return .task { .initDownloads }
                    .delay(for: .seconds(0.2), scheduler: mainQueue)
                    .eraseToEffect()
                
            case .cachedMangaThumbnailAction(_, .userLeftMangaView):
                return .task { .initDownloads }
                    .delay(for: .seconds(0.2), scheduler: mainQueue)
                    .eraseToEffect()
                
            case .sortOrderChanged(let newSortOrder):
                state.currentSortOrder = newSortOrder
                
                switch newSortOrder {
                case .alphabeticallyAsc:
                    state.cachedMangaThumbnailStates.sort(by: { $0.manga.title < $1.manga.title })
                case .alphabeticallyDesc:
                    state.cachedMangaThumbnailStates.sort(by: { $0.manga.title > $1.manga.title })
                case .firstAdded:
                    state.cachedMangaThumbnailStates.sort(
                        by: { state.mangaEntries[id: $0.manga.id]!.addedAt < state.mangaEntries[id: $1.manga.id]!.addedAt }
                    )
                case .lastAdded:
                    state.cachedMangaThumbnailStates.sort(
                        by: { state.mangaEntries[id: $0.manga.id]!.addedAt > state.mangaEntries[id: $1.manga.id]!.addedAt }
                    )
                }
                
                return .none
                
            case .cachedMangaThumbnailAction:
                return .none
            }
        }
        .forEach(\.cachedMangaThumbnailStates, action: /Action.cachedMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
    }
}
