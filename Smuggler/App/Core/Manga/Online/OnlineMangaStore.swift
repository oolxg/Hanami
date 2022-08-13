//
//  MangaFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

struct OnlineMangaViewState: Equatable {
    let manga: Manga
    var pagesState: PagesState?
    
    var areVolumesLoaded = false
    var shouldShowEmptyMangaMessage: Bool {
        areVolumesLoaded && pagesState != nil && pagesState!.splitIntoPagesVolumeTabStates.isEmpty
    }

    init(manga: Manga) {
        self.manga = manga
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
        allCoverArtsInfo.compactMap(\.coverArtURL512)
    }
    
    // should only be used for clearing cache
    mutating func reset() {
        let manga = manga
        let stat = statistics
        let coverArtURL = mainCoverArtURL
        let coverArtURL256 = coverArtURL256
        
        self = OnlineMangaViewState(manga: manga)
        self.statistics = stat
        self.mainCoverArtURL = coverArtURL
        self.coverArtURL256 = coverArtURL256
    }
    
    struct CancelClearCacheForManga: Hashable { let mangaID: UUID }
}

enum OnlineMangaViewAction: BindableAction {
    // MARK: - Actions to be called from view
    case onAppear
    case mangaTabChanged(OnlineMangaViewState.Tab)

    // MARK: - Actions to be called from reducer
    case volumesDownloaded(Result<VolumesContainer, AppError>)
    case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, AppError>)
    case sameScanlationGroupChaptersFetched(Result<VolumesContainer, AppError>)
    case allCoverArtsInfoFetched(Result<Response<[CoverArtInfo]>, AppError>)
    
    case pagesInfoForChapterCachingFetched(Result<ChapterPagesInfo, AppError>, ChapterDetails)
    case chapterPageForCachingFetched(Result<UIImage, Error>, Int, ChapterDetails)
    case coverArtFetched(Result<UIImage, Error>)
    
    // MARK: - Substate actions
    case mangaReadingViewAction(MangaReadingViewAction)
    case pagesAction(PagesAction)
    
    // MARK: - Binding
    case binding(BindingAction<OnlineMangaViewState>)
}

struct MangaViewEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
    let imageClient: ImageClient
    let cacheClient: CacheClient
    let hudClient: HUDClient
}

let onlineMangaViewReducer: Reducer<OnlineMangaViewState, OnlineMangaViewAction, MangaViewEnvironment> = .combine(
    pagesReducer.optional().pullback(
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
            mangaClient: $0.mangaClient,
            imageClient: $0.imageClient
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                var effects: [Effect<OnlineMangaViewAction, Never>] = []
                
                if state.pagesState == nil {
                    effects.append(
                        env.mangaClient.fetchMangaChapters(state.manga.id, nil, nil)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(OnlineMangaViewAction.volumesDownloaded)
                    )
                }
                
                if state.statistics == nil {
                    effects.append(
                        env.mangaClient.fetchMangaStatistics(state.manga.id)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(OnlineMangaViewAction.mangaStatisticsDownloaded)
                        )
                }
                
                return effects.isEmpty ? .none : .merge(effects)
                
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
                        env.hudClient.show(message: error.description)
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
                
            case .sameScanlationGroupChaptersFetched:
                return .none
            
            case .mangaReadingViewAction:
                return .none
                
            case .pagesAction:
                return .none
                
            case .pagesInfoForChapterCachingFetched:
                return .none
                
            case .chapterPageForCachingFetched:
                return .none
                
            case .coverArtFetched:
                return .none
                
            case .binding:
                return .none
        }
    }
    .binding(),
    // MARK: - Actions for caching chapters
    // separeted logic for handling download actions(for offline reading
    Reducer { state, action, env in
        switch action {
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .downloadChapterForOfflineReading(let chapter)))):
                var effects: [Effect<OnlineMangaViewAction, Never>] = [
                    env.mangaClient.fetchPagesInfo(chapter.id)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { OnlineMangaViewAction.pagesInfoForChapterCachingFetched($0, chapter) }
                ]
                
                // check if we already loaded this manga and if yes, means cover art is cached already, so we don't do it again
                if !env.mangaClient.isCoverArtCached(state.manga.id, env.cacheClient), let coverArtURL = state.mainCoverArtURL {
                    effects.append(
                        env.imageClient.downloadImage(coverArtURL, nil)
                            .receive(on: DispatchQueue.main)
                            .eraseToEffect(OnlineMangaViewAction.coverArtFetched)
                    )
                }
                
                return .merge(effects)
                
            case .pagesInfoForChapterCachingFetched(let result, let chapter):
                switch result {
                    case .success(let pagesInfo):
                        var effects = pagesInfo
                            .dataURLs
                            .enumerated()
                            .map { i, url in
                                env.imageClient.downloadImage(url, nil)
                                    .eraseToEffect {
                                        OnlineMangaViewAction.chapterPageForCachingFetched($0, i, chapter)
                                    }
                            }
                        
                        effects.append(
                            env.databaseClient
                                .saveChapterDetails(
                                    chapter,
                                    pagesCount: pagesInfo.dataURLs.count,
                                    fromManga: state.manga
                                )
                                .fireAndForget()
                        )
                        
                        return .merge(effects)
                        
                    case .failure(let error):
                        print("Error on fetching PagesInfo for caching: \(error)")
                        return .none
                }
                
            case .coverArtFetched(let result):
                switch result {
                    case .success(let coverArt):
                        return env.mangaClient
                            .saveCoverArt(coverArt, state.manga.id, env.cacheClient)
                            .fireAndForget()
                        
                    case .failure(let error):
                        print("Error on fetching coverArt for caching: \(error.localizedDescription)")
                        return .none
                }
                
            case .chapterPageForCachingFetched(let result, let pageIndex, let chapter):
                switch result {
                    case .success(let chapterPage):
                        return env.mangaClient
                            .saveChapterPage(chapterPage, pageIndex, chapter.id, env.cacheClient)
                            .fireAndForget()
                        
                    case .failure(let error):
                        print("Error on fetching chapterPage(image) for caching: \(error.localizedDescription)")
                        return .none
                }
                
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userConfirmedChapterDeletion(let chapter)))):
                var effects: [Effect<OnlineMangaViewAction, Never>] = [
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
                
            default:
                return .none
        }
    },
    // MARK: - MangaReadingViewAction
    // separated action from MangaReadingView
    Reducer { state, action, env in
        switch action {
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
                
            // here we're fetching all chapters from the same scanlation group, that translated current reading chapter
            case .sameScanlationGroupChaptersFetched(let result):
                switch result {
                    case .success(let response):
                        state.sameScanlationGroupChapters = response.volumes.flatMap(\.chapters).reversed()
                        
                        return .none
                        
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error)")
                        return .none
                }
                
            case .mangaReadingViewAction(.userHitLastPage):
                let nextChapterIndex = env.mangaClient.computeNextChapterIndex(
                    state.mangaReadingViewState?.chapterIndex, state.sameScanlationGroupChapters
                )
                
                guard let nextChapterIndex = nextChapterIndex,
                      let nextChapter = state.sameScanlationGroupChapters?[nextChapterIndex] else {
                    state.isUserOnReadingView = false
                    env.hudClient.show(message: "🙁 You've read the last chapter from this scanlation group.")
                    return Effect(value: .mangaReadingViewAction(.userLeftMangaReadingView))
                }
                
                state.mangaReadingViewState = MangaReadingViewState(
                    chapterID: nextChapter.id,
                    chapterIndex: nextChapter.chapterIndex
                )
                
                if let pageIndex = env.mangaClient.getMangaPaginationPageForReadingChapter(
                    nextChapter.chapterIndex, state.pagesState!.splitIntoPagesVolumeTabStates
                ) {
                    return Effect(value: .pagesAction(.changePage(newPageIndex: pageIndex)))
                }
                
                return .none
                
            case .mangaReadingViewAction(.userHitTheMostFirstPage):
                let previousChapterIndex = env.mangaClient.computePreviousChapterIndex(
                    state.mangaReadingViewState?.chapterIndex, state.sameScanlationGroupChapters
                )
                
                guard let previousChapterIndex = previousChapterIndex,
                      let previousChapter = state.sameScanlationGroupChapters?[previousChapterIndex] else {
                    state.isUserOnReadingView = false
                    env.hudClient.show(message: "🤔 You've read the first chapter from this scanlation group.")
                    return Effect(value: .mangaReadingViewAction(.userLeftMangaReadingView))
                }
                
                state.mangaReadingViewState = MangaReadingViewState(
                    chapterID: previousChapter.id,
                    chapterIndex: previousChapter.chapterIndex,
                    shouldSendUserToTheLastPage: true
                )
                
                if let pageIndex = env.mangaClient.getMangaPaginationPageForReadingChapter(
                    previousChapter.chapterIndex, state.pagesState!.splitIntoPagesVolumeTabStates
                ) {
                    return Effect(value: .pagesAction(.changePage(newPageIndex: pageIndex)))
                }
                
                return .none
                
            case .mangaReadingViewAction(.userLeftMangaReadingView):
                defer { state.isUserOnReadingView = false }
                
                let chapterIndex = state.mangaReadingViewState!.chapterIndex
                let volumes = state.pagesState!.volumeTabStatesOnCurrentPage
                
                guard let info = env.mangaClient.getReadChapterOnPaginationPage(chapterIndex, volumes) else {
                    return .none
                }
                
                if state.pagesState!
                    .volumeTabStatesOnCurrentPage[id: info.volumeID]!
                    .chapterStates[id: info.chapterID]!
                    .areChaptersShown {
                    return .none
                }
                
                return Effect(
                    value: .pagesAction(
                        .volumeTabAction(
                            volumeID: info.volumeID,
                            volumeAction: .chapterAction(
                                id: info.chapterID,
                                action: .fetchChapterDetailsIfNeeded
                            )
                        )
                    )
                )
                
            default:
                return .none
        }
    }
)
