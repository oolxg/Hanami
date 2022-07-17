//
//  MangaFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import Kingfisher

struct MangaViewState: Equatable {
    let manga: Manga
    
    var statistics: MangaStatistics?

    var pagesState: PagesState? {
        willSet { areVolumesLoaded = newValue != nil }
    }
    var currentPageIndex: Int = 0
    
    var areVolumesLoaded = false
    var shouldShowEmptyMangaMessage: Bool {
        pagesState != nil && pagesState!.volumeTabStatesOnCurrentPage.isEmpty
    }
    
    var allCoverArtsInfo: [CoverArtInfo] = []

    var selectedTab: Tab = .chapters
    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case about = "About"
        case coverArt = "Art"
        
        var id: String { rawValue }
    }
    
    @BindableState var hudInfo = HUDInfo()
    
    // MARK: - Props for MangaReadingView
    @BindableState var isUserOnReadingView = false
    // it's better not to set value of 'mangaReadingViewState' to nil
    @BindableState var mangaReadingViewState: MangaReadingViewState? {
        willSet {
            isUserOnReadingView = newValue != nil
        }
    }
    // if user starts reading some chapter, we fetch all chapters from the same scanlation group
    var sameScanlationGroupChapters: [Chapter]?
     
    var mainCoverArtURL: URL?
    var coverArtURL512: URL?
    var croppedCoverArtURLs: [URL] {
        allCoverArtsInfo.compactMap { $0.coverArtURL512 }
    }
    
    // should only be used for clearing cache
    mutating func reset() {
        let manga = manga
        let stat = statistics
        let coverArtURL = mainCoverArtURL
        
        self = MangaViewState(manga: manga)
        self.statistics = stat
        self.mainCoverArtURL = coverArtURL
    }
}

enum MangaViewAction: BindableAction {
    // MARK: - Actions to be called from view
    case onAppear
    case mangaTabChanged(MangaViewState.Tab)

    // MARK: - Actions to be called from reducer
    case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, AppError>)
    case volumesDownloaded(Result<VolumesContainer, AppError>)
    case sameScanlationGroupChaptersFetched(Result<VolumesContainer, AppError>)
    case allCoverArtsInfoFetched(Result<Response<[CoverArtInfo]>, AppError>)
    
    // MARK: - Substate actions
    case mangaReadingViewAction(MangaReadingViewAction)
    case pagesAction(PagesAction)
    
    // MARK: - Binding
    case binding(BindingAction<MangaViewState>)
}

struct MangaViewEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
}

let mangaViewReducer: Reducer<MangaViewState, MangaViewAction, MangaViewEnvironment> = .combine(
    pagesReducer.optional().pullback(
        state: \.pagesState,
        action: /MangaViewAction.pagesAction,
        environment: { .init(
            mangaClient: $0.mangaClient,
            databaseClient: $0.databaseClient
        ) }
    ),
    mangaReadingViewReducer.optional().pullback(
        state: \.mangaReadingViewState,
        action: /MangaViewAction.mangaReadingViewAction,
        environment: { .init(
            mangaClient: $0.mangaClient
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                var effects: [Effect<MangaViewAction, Never>] = []
                
                if state.statistics == nil {
                    effects.append(
                        env.mangaClient.fetchMangaStatistics(state.manga.id)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(MangaViewAction.mangaStatisticsDownloaded)
                    )
                }
                
                if state.pagesState == nil {
                    effects.append(
                        // we are loading here all chapters, no need to select lang or scanlation group
                        env.mangaClient.fetchMangaChapters(state.manga.id, nil, nil)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(MangaViewAction.volumesDownloaded)
                    )
                }
                        
                return effects.isEmpty ? .none : .merge(effects)
                
            case .mangaTabChanged(let newTab):
                state.selectedTab = newTab
                
                if newTab == .coverArt && state.allCoverArtsInfo.isEmpty {
                    return env.mangaClient.fetchAllCoverArtsInfForManga(state.manga.id)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(MangaViewAction.allCoverArtsInfoFetched)
                }
                
                return .none
                
            case .allCoverArtsInfoFetched(let result):
                switch result {
                    case .success(let response):
                        state.allCoverArtsInfo = response.data
                        return .none
                        
                    case .failure(let error):
                        print("error on fetching allCoverArtsInfo, \(error)")
                        return .none
                }

            case .volumesDownloaded(let result):
                state.areVolumesLoaded = true
                switch result {
                    case .success(let response):
                        state.pagesState = PagesState(mangaVolumes: response.volumes, chaptersPerPage: 10)
                        
                        return .none
                        
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error)")
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
                        state.sameScanlationGroupChapters = response.volumes.flatMap(\.chapters).sorted(by: <)
                                            
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
                    chapter.scanltaionGroupID,
                    chapter.attributes.translatedLanguage
                )
                .receive(on: DispatchQueue.main)
                .catchToEffect(MangaViewAction.sameScanlationGroupChaptersFetched)
                
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
                    nextChapter.chapterIndex, state.pagesState!.splittedIntoPagesVolumeTabStates
                ) {
                    return Effect(value: MangaViewAction.pagesAction(.changePage(newPageIndex: pageIndex)))
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
                    shoudSendUserToTheLastPage: true
                )
                
                if let pageIndex = env.mangaClient.getMangaPaginationPageForReadingChapter(
                    previousChapter.chapterIndex, state.pagesState!.splittedIntoPagesVolumeTabStates
                ) {
                    return Effect(value: MangaViewAction.pagesAction(.changePage(newPageIndex: pageIndex)))
                }
                
                return .none
                
            case .mangaReadingViewAction(.userLeftMangaReadingView):
                let chapterIndex = state.mangaReadingViewState!.chapterIndex
                let volumes = state.pagesState!.volumeTabStatesOnCurrentPage
                
                let info = env.mangaClient.getReadChapterOnPaginationPage(chapterIndex, volumes)
                state.isUserOnReadingView = false
                
                if let info = info {
                    return Effect(
                        value: MangaViewAction.pagesAction(
                            .volumeTabAction(
                                volumeID: info.volumeID,
                                volumeAction: .chapterAction(
                                    id: info.chapterID,
                                    action: .fetchChapterDetailsIfNeeded
                                )
                            )
                        )
                    )
                }
                
                return .none
                
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
