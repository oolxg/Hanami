//
//  DownloadsStore.swift
//  Hanami
//
//  Created by Oleg on 19/07/2022.
//

import Foundation
import ComposableArchitecture
import ModelKit
import Logger
import ImageClient

@Reducer
struct DownloadsFeature {
    struct State: Equatable {
        var cachedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var mangaEntries: IdentifiedArrayOf<CoreDataMangaEntry> = []
        var currentSortOrder = SortOrder.firstAdded
    }
    
    enum Action {
        case initDownloads
        case cachedMangaFetched([CoreDataMangaEntry])
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
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .initDownloads:
                return .run { send in
                    let cachedManga = await databaseClient.retrieveAllCachedMangas()
                    await send(.cachedMangaFetched(cachedManga))
                }
                
            case .cachedMangaFetched(let cachedManga):
                let cachedMangaIDsSet = state.cachedMangaThumbnailStates.ids
                let retrievedMangaIDs = cachedManga.ids
                let stateIDsToLeave = cachedMangaIDsSet.intersection(retrievedMangaIDs)
                let newMangaIDs = retrievedMangaIDs.subtracting(stateIDsToLeave)
                
                state.cachedMangaThumbnailStates.removeAll(where: { !stateIDsToLeave.contains($0.id) })
                
                state.mangaEntries = cachedManga.asIdentifiedArray
                
                for entry in cachedManga where newMangaIDs.contains(entry.manga.id) {
                    state.cachedMangaThumbnailStates.append(
                        MangaThumbnailFeature.State(manga: entry.manga, online: false)
                    )
                }
                
                let coverArtPaths = state.cachedMangaThumbnailStates.map(\.thumbnailURL).compactMap { $0 }
                imageClient.prefetchImages(with: coverArtPaths)
                
                return .none

            case .cachedMangaThumbnailAction(_, .offlineMangaAction(.deleteMangaButtonTapped)):
                return .run { send in
                    try await Task.sleep(seconds: 0.2)
                    await send(.initDownloads)
                }
                
            case .cachedMangaThumbnailAction(_, .navLinkValueDidChange(false)):
                return .run { send in
                    try await Task.sleep(seconds: 0.2)
                    await send(.initDownloads)
                }

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
