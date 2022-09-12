//
//  OfflineMangaViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/07/2022.
//

import Foundation
import ComposableArchitecture

struct OfflineMangaViewState: Equatable {
    let manga: Manga
    var coverArtPath: URL?
    
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
    var mangaReadingViewState: MangaReadingViewState?
}

enum OfflineMangaViewAction: BindableAction {
    case onAppear
    case cachedChaptersRetrieved(Result<[(chapter: ChapterDetails, pagesCount: Int)], AppError>)
    case mangaTabChanged(OfflineMangaViewState.Tab)
    case deleteManga
    case chaptersForMangaDeletionRetrieved(Result<[(chapter: ChapterDetails, pagesCount: Int)], AppError>)
    
    case mangaReadingViewAction(MangaReadingViewAction)
    case pagesAction(PagesAction)
    
    case binding(BindingAction<OfflineMangaViewState>)
}


let offlineMangaViewReducer: Reducer<OfflineMangaViewState, OfflineMangaViewAction, MangaViewEnvironment> = .combine(
    pagesReducer.optional().pullback(
        state: \.pagesState,
        action: /OfflineMangaViewAction.pagesAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            imageClient: $0.imageClient,
            cacheClient: $0.cacheClient,
            mangaClient: $0.mangaClient,
            hudClient: $0.hudClient
        ) }
    ),
    mangaReadingViewReducer.optional().pullback(
        state: \.mangaReadingViewState,
        action: /OfflineMangaViewAction.mangaReadingViewAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            cacheClient: $0.cacheClient,
            imageClient: $0.imageClient,
            mangaClient: $0.mangaClient,
            hudClient: $0.hudClient
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                return env.databaseClient
                    .retrieveChaptersForManga(mangaID: state.manga.id)
                    .catchToEffect(OfflineMangaViewAction.cachedChaptersRetrieved)
                
            case .cachedChaptersRetrieved(let result):
                switch result {
                    case .success(let chapters):
                        // here we're checking if chapters, we've fetched, and chapters, we've fetched before are same
                        // if yes, we should do nothing
                        let chaptersIDsSet = Set(chapters.map(\.chapter.id))
                        guard state.lastRetrievedChapterIDs != chaptersIDsSet else {
                            return .none
                        }

                        state.lastRetrievedChapterIDs = chaptersIDsSet
                        state.pagesState = PagesState(
                            manga: state.manga,
                            chaptersDetailsList: chapters.map(\.chapter),
                            chaptersPerPages: 15
                        )
                        return .none

                    case .failure(let error):
                        print("Error on retrieving chapters:", error)
                        return .none
                }

            case .mangaTabChanged(let tab):
                state.selectedTab = tab
                return .none
                
            case .deleteManga:
                return env.databaseClient.retrieveChaptersForManga(mangaID: state.manga.id)
                    .catchToEffect(OfflineMangaViewAction.chaptersForMangaDeletionRetrieved)
                
            case .chaptersForMangaDeletionRetrieved(let result):
                switch result {
                    case .success(let chapters):
                        return .concatenate(
                            env.databaseClient.deleteManga(mangaID: state.manga.id)
                                .fireAndForget(),
                            
                            .merge(
                                chapters.map { chapterEntity in
                                    env.mangaClient
                                        .removeCachedPagesForChapter(chapterEntity.chapter.id, chapterEntity.pagesCount, env.cacheClient)
                                        .fireAndForget()
                                }
                            )
                        )
                        
                    case .failure(let error):
                        print("Error on retrieving chapters:", error)
                        return .none
                }

                
            case .pagesAction:
                return .none
                
            case .mangaReadingViewAction:
                return .none
                
            case .binding:
                return .none
        }
    }
    .binding(),
    // Handling actions from MangaReadingView
    Reducer { state, action, env in
        switch action {
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userTappedOnChapterDetails(let chapter)))):
                guard let retrievedChapter = env.databaseClient.fetchChapter(chapterID: chapter.id) else {
                    env.hudClient.show(message: "😢 Error on retrieving saved chapter")
                    return .none
                }
                
                state.mangaReadingViewState = .offline(
                    OfflineMangaReadingViewState(
                        mangaID: state.manga.id,
                        chapter: retrievedChapter.chapter,
                        pagesCount: retrievedChapter.pagesCount,
                                            startFromLastPage: false
                    )
                )
                
                state.isUserOnReadingView = true

                return .task { .mangaReadingViewAction(.offline(.userStartedReadingChapter)) }
                
            case .mangaReadingViewAction(.offline(.userStartedReadingChapter)):
                if let pageIndex = env.mangaClient.getMangaPageForReadingChapter(
                    state.mangaReadingViewState?.chapterIndex, state.pagesState!.splitIntoPagesVolumeTabStates
                ) {
                    return .task { .pagesAction(.changePage(newPageIndex: pageIndex)) }
                }
                
                return .none

            case .mangaReadingViewAction(.offline(.userLeftMangaReadingView)):
                defer { state.isUserOnReadingView = false }

                let chapterIndex = state.mangaReadingViewState!.chapterIndex
                let volumes = state.pagesState!.volumeTabStatesOnCurrentPage

                guard let info = env.mangaClient.findDidReadChapterOnMangaPage(chapterIndex, volumes) else {
                    return .none
                }
                
                // chapterState, on which user has left MangaReadingView
                let chapterState = state.pagesState!
                    .volumeTabStatesOnCurrentPage[id: info.volumeID]!
                    .chapterStates[id: info.chapterID]!
                
                if chapterState.areChaptersShown {
                    return .none
                }

                return .task {
                    .pagesAction(
                        .volumeTabAction(
                            volumeID: info.volumeID,
                            volumeAction: .chapterAction(
                                id: info.chapterID,
                                action: .fetchChapterDetailsIfNeeded
                            )
                        )
                    )
                }

            default:
                return .none
        }
    }
)
