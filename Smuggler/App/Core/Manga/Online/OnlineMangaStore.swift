//
//  MangaFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import Kingfisher

struct OnlineMangaViewState: Equatable {
    let manga: Manga
    var pagesState: PagesState

    init(manga: Manga) {
        self.manga = manga
        pagesState = PagesState(manga: manga, chaptersPerPage: 10)
    }
    
    var statistics: MangaStatistics?
    
    var allCoverArtsInfo: [CoverArtInfo] = []

    var selectedTab: Tab = .chapters
    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case info = "Info"
        case coverArt = "Art"
        
        var id: String { rawValue }
    }
    
    @BindableState var hudInfo = HUDInfo()
    
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
    var coverArtURL256: URL?
    var croppedCoverArtURLs: [URL] {
        allCoverArtsInfo.compactMap { $0.coverArtURL512 }
    }
    
    var mangaLink: URL {
        URL(string: "https://mangadex.org/title/\(manga.id.uuidString.lowercased())")!
    }
    
    // should only be used for clearing cache
    mutating func reset() {
        let manga = manga
        let stat = statistics
        let coverArtURL = mainCoverArtURL
        
        self = OnlineMangaViewState(manga: manga)
        self.statistics = stat
        self.mainCoverArtURL = coverArtURL
    }
    
    struct CancelClearCacheForManga: Hashable { let mangaID: UUID }
}

enum OnlineMangaViewAction: BindableAction {
    // MARK: - Actions to be called from view
    case onAppear
    case mangaTabChanged(OnlineMangaViewState.Tab)

    // MARK: - Actions to be called from reducer
    case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, AppError>)
    case sameScanlationGroupChaptersFetched(Result<VolumesContainer, AppError>)
    case allCoverArtsInfoFetched(Result<Response<[CoverArtInfo]>, AppError>)
    
    // MARK: - Substate actions
    case mangaReadingViewAction(MangaReadingViewAction)
    case pagesAction(PagesAction)
    
    // MARK: - Binding
    case binding(BindingAction<OnlineMangaViewState>)
}

struct MangaViewEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
}

let onlineMangaViewReducer: Reducer<OnlineMangaViewState, OnlineMangaViewAction, MangaViewEnvironment> = .combine(
    pagesReducer.pullback(
        state: \.pagesState,
        action: /OnlineMangaViewAction.pagesAction,
        environment: { .init(
            mangaClient: $0.mangaClient,
            databaseClient: $0.databaseClient
        ) }
    ),
    mangaReadingViewReducer.optional().pullback(
        state: \.mangaReadingViewState,
        action: /OnlineMangaViewAction.mangaReadingViewAction,
        environment: { .init(
            mangaClient: $0.mangaClient
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                if state.statistics == nil {
                    return env.mangaClient.fetchMangaStatistics(state.manga.id)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(OnlineMangaViewAction.mangaStatisticsDownloaded)
                }
                
                return .none
                
            case .mangaTabChanged(let newTab):
                state.selectedTab = newTab
                
                if newTab == .coverArt && state.allCoverArtsInfo.isEmpty {
                    return env.mangaClient.fetchAllCoverArtsForManga(state.manga.id)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(OnlineMangaViewAction.allCoverArtsInfoFetched)
                }
                
                return .none
                
            case .allCoverArtsInfoFetched(let result):
                switch result {
                    case .success(let response):
                        state.allCoverArtsInfo = response.data
                        return .none
                        
                    case .failure(let error):
                        state.hudInfo.message = error.description
                        state.hudInfo.show = true
                        print("error on fetching allCoverArtsInfo, \(error)")
                        return .none
                }
                
            case .mangaStatisticsDownloaded(let result):
                switch result {
                    case .success(let response):
                        state.statistics = response.statistics[state.manga.id]
                        return .none
                        
                    case .failure(let error):
                        print("error on mangaFetchStatistics, \(error)")
                        return .none
                }
                
            // here we're fetching all chapters from the same scanlation group, that translated current reading chapter
            case .sameScanlationGroupChaptersFetched(let result):
                switch result {
                    case .success(let response):
                        state.sameScanlationGroupChapters = response.volumes.flatMap(\.chapters)
                                            
                        return .none
                        
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error)")
                        return .none
                }
                
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userTappedOnChapterDetails(let chapter)))):
                let newMangaReadingViewState = MangaReadingViewState(
                    chapterID: chapter.id,
                    chapterIndex: chapter.attributes.chapterIndex
                )
                
                if state.mangaReadingViewState?.chapterID != newMangaReadingViewState.chapterID {
                    state.mangaReadingViewState = newMangaReadingViewState
                } else {
                    state.isUserOnReadingView = true
                }
                
                return env.mangaClient.fetchMangaChapters(
                    state.manga.id,
                    chapter.scanlationGroupID,
                    chapter.attributes.translatedLanguage
                )
                .receive(on: DispatchQueue.main)
                .catchToEffect(OnlineMangaViewAction.sameScanlationGroupChaptersFetched)
                
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .downloadChapterForOfflineReading(let chapter)))):
                return env.databaseClient.saveChapterDetails(chapter, fromManga: state.manga).fireAndForget()
                
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userConfirmedChapterDelete(let chapter)))):
                return env.databaseClient.deleteChapter(id: chapter.id).fireAndForget()
                
            case .mangaReadingViewAction(.userHitLastPage):
                let nextChapterIndex = env.mangaClient.computeNextChapterIndex(
                    state.mangaReadingViewState?.chapterIndex, state.sameScanlationGroupChapters
                )
                
                guard let nextChapterIndex = nextChapterIndex,
                      let nextChapter = state.sameScanlationGroupChapters?[nextChapterIndex] else {
                    state.isUserOnReadingView = false
                    state.hudInfo.show = true
                    state.hudInfo.message = "🙁 You've read the last chapter from this scanlation group."
                    return .none
                }
                
                state.mangaReadingViewState = MangaReadingViewState(
                    chapterID: nextChapter.id,
                    chapterIndex: nextChapter.chapterIndex
                )
                
                if let pageIndex = env.mangaClient.getMangaPaginationPageForReadingChapter(
                    nextChapter.chapterIndex, state.pagesState.splitIntoPagesVolumeTabStates
                ) {
                    return Effect(value: OnlineMangaViewAction.pagesAction(.changePage(newPageIndex: pageIndex)))
                }
                
                return .none

            case .mangaReadingViewAction(.userHitTheMostFirstPage):
                let previousChapterIndex = env.mangaClient.computePreviousChapterIndex(
                    state.mangaReadingViewState?.chapterIndex, state.sameScanlationGroupChapters
                )
                
                guard let previousChapterIndex = previousChapterIndex,
                      let previousChapter = state.sameScanlationGroupChapters?[previousChapterIndex] else {
                    state.isUserOnReadingView = false
                    state.hudInfo.show = true
                    state.hudInfo.message = "🤔 You've read the first chapter from this scanlation group."
                    return .none
                }
                
                state.mangaReadingViewState = MangaReadingViewState(
                    chapterID: previousChapter.id,
                    chapterIndex: previousChapter.chapterIndex,
                    shouldSendUserToTheLastPage: true
                )
                
                if let pageIndex = env.mangaClient.getMangaPaginationPageForReadingChapter(
                    previousChapter.chapterIndex, state.pagesState.splitIntoPagesVolumeTabStates
                ) {
                    return Effect(value: OnlineMangaViewAction.pagesAction(.changePage(newPageIndex: pageIndex)))
                }
                
                return .none
                
            case .mangaReadingViewAction(.userLeftMangaReadingView):
                defer { state.isUserOnReadingView = false }
                
                let chapterIndex = state.mangaReadingViewState!.chapterIndex
                let volumes = state.pagesState.volumeTabStatesOnCurrentPage
                
                guard let info = env.mangaClient.getReadChapterOnPaginationPage(chapterIndex, volumes) else {
                    return .none
                }
                
                if state.pagesState
                    .volumeTabStatesOnCurrentPage[id: info.volumeID]!
                    .chapterStates[id: info.chapterID]!
                    .areChaptersShown {
                    return .none
                }
                
                return Effect(
                    value: OnlineMangaViewAction.pagesAction(
                        .volumeTabAction(
                            volumeID: info.volumeID,
                            volumeAction: .chapterAction(
                                id: info.chapterID,
                                action: .fetchChapterDetailsIfNeeded
                            )
                        )
                    )
                )
                
            case .mangaReadingViewAction:
                return .none
                
            case .pagesAction:
                return .none
                
            case .binding:
                return .none
        }
    }
    .binding()
)
