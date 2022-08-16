//
//  OfflineMangaViewStore.swift
//  Smuggler
//
//  Created by mk.pwnz on 23/07/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

struct OfflineMangaViewState: Equatable {
    let manga: Manga
    var coverArt: UIImage?
    
    // to compare with cached chapters, we retrieved last time
    var lastRetrievedChapterIDs: Set<UUID> = []
    
    init(manga: Manga) {
        self.manga = manga
    }
    
    var pagesState: PagesState?
    
    var selectedTab: Tab = .chapters
    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case info = "Info"
        
        var id: String { rawValue }
    }
    
    // MARK: - Props for MangaReadingView
    @BindableState var isUserOnReadingView = false
    // it's better not to set value of 'mangaReadingViewState' to nil
    var mangaReadingViewState: MangaReadingViewState? {
        willSet {
            isUserOnReadingView = newValue != nil
        }
    }
    // if user starts reading some chapter, we fetch all chapters from the same scanlation group
    var sameScanlationGroupChapters: [Chapter]?
    
    var mainCoverArtURL: URL?
    
    // should only be used for clearing cache
    mutating func reset() {
        let manga = manga
        let coverArtURL = mainCoverArtURL
        
        self = OfflineMangaViewState(manga: manga)
        self.mainCoverArtURL = coverArtURL
    }
    
    struct CancelClearCacheForManga: Hashable { let mangaID: UUID }
}

enum OfflineMangaViewAction: BindableAction {
    case onAppear
    case cachedChaptersRetrieved(Result<[ChapterDetails], AppError>)
    case mangaTabChanged(OfflineMangaViewState.Tab)
    
    case mangaReadingViewAction(MangaReadingViewAction)
    case pagesAction(PagesAction)
    
    case binding(BindingAction<OfflineMangaViewState>)
}


let offlineMangaViewReducer: Reducer<OfflineMangaViewState, OfflineMangaViewAction, MangaViewEnvironment> = .combine(
    pagesReducer.optional().pullback(
        state: \.pagesState,
        action: /OfflineMangaViewAction.pagesAction,
        environment: { .init(
            mangaClient: $0.mangaClient,
            databaseClient: $0.databaseClient
        ) }
    ),
    mangaReadingViewReducer.optional().pullback(
        state: \.mangaReadingViewState,
        action: /OfflineMangaViewAction.mangaReadingViewAction,
        environment: { .init(
            mangaClient: $0.mangaClient,
            imageClient: $0.imageClient
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                return env.databaseClient
                    .fetchChaptersForManga(mangaID: state.manga.id)
                    .catchToEffect(OfflineMangaViewAction.cachedChaptersRetrieved)
                
            case .cachedChaptersRetrieved(let result):
                switch result {
                    case .success(let chapters):
                        // here we're checking if chapters, we've fetched, and chapters, we've fetched before are same
                        // if yes, we should do nothing
                        let chaptersIDsSet = Set(chapters.map(\.id))
                        guard state.lastRetrievedChapterIDs != chaptersIDsSet else {
                            return .none
                        }

                        state.lastRetrievedChapterIDs = chaptersIDsSet
                        state.pagesState = PagesState(chaptersDetailsList: chapters, chaptersPerPages: 10)
                        return .none

                    case .failure(let error):
                        print("Error on retrieving chapters:", error)
                        return .none
                }

            case .mangaTabChanged(let tab):
                state.selectedTab = tab
                return .none
                
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .chapterDeletionConfirmed(let chapter)))):
                var effects: [Effect<OfflineMangaViewAction, Never>] = [
                    env.databaseClient
                        .deleteChapter(chapterID: chapter.id)
                        .fireAndForget()
                ]
                
                if let pagesCount = env.databaseClient.fetchChapterPagesCount(chapterID: chapter.id) {
                    effects.append(
                        env.mangaClient
                            .removeCachedPagesForChapter(chapter.id, pagesCount, env.cacheClient)
                            .fireAndForget()
                    )
                }
                
                return .merge(effects)
                
            case .pagesAction:
                return .none
                
            case .mangaReadingViewAction:
                return .none
                
            case .binding:
                return .none
        }
    }
    .binding()
)
