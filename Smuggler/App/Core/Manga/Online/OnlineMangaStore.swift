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
    var mangaReadingViewState: MangaReadingViewState? {
        willSet {
            isUserOnReadingView = newValue != nil
        }
    }
     
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
    
    struct CancelClearCache: Hashable { let mangaID: UUID }
}

enum OnlineMangaViewAction: BindableAction {
    // MARK: - Actions to be called from view
    case onAppear
    case mangaTabChanged(OnlineMangaViewState.Tab)

    // MARK: - Actions to be called from reducer
    case volumesDownloaded(Result<VolumesContainer, AppError>)
    case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, AppError>)
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
    let hapticClient: HapticClient
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
            imageClient: $0.imageClient,
            hudClient: $0.hudClient,
            databaseClient: $0.databaseClient,
            cacheClient: $0.cacheClient
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
                        state.pagesState = PagesState(
                            mangaVolumes: response.volumes,
                            chaptersPerPage: 10,
                            isOnline: true
                        )
                        
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
                
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .chapterDeletionConfirmed(let chapter)))):
                var effects: [Effect<OnlineMangaViewAction, Never>] = [
                    env.databaseClient
                        .deleteChapter(chapterID: chapter.id)
                        .fireAndForget()
                ]
                
                if let pagesCount = env.databaseClient.fetchChapter(chapterID: chapter.id)?.pagesCount {
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
    // MARK: - Actions to read chapter
    // separated actions from MangaReadingView
    Reducer { state, action, env in
        switch action {
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userTappedOnChapterDetails(let chapter)))):
                state.mangaReadingViewState = .online(
                    OnlineMangaReadingViewState(
                        mangaID: state.manga.id,
                        chapterID: chapter.id,
                        chapterIndex: chapter.attributes.chapterIndex,
                        scanlationGroupID: chapter.scanlationGroupID,
                        translatedLanguage: chapter.attributes.translatedLanguage
                    )
                )

                return Effect(value: .mangaReadingViewAction(.online(.userStartedReadingChapter)))
                
            case .mangaReadingViewAction(.online(.userStartedReadingChapter)):
                if let pageIndex = env.mangaClient.getMangaPaginationPageForReadingChapter(
                    state.mangaReadingViewState?.chapterIndex, state.pagesState!.splitIntoPagesVolumeTabStates
                ) {
                    return Effect(value: .pagesAction(.changePage(newPageIndex: pageIndex)))
                }
                
                return .none

                
            case .mangaReadingViewAction(.online(.userLeftMangaReadingView)):
                defer { state.isUserOnReadingView = false }
                
                let chapterIndex = state.mangaReadingViewState!.chapterIndex
                let volumes = state.pagesState!.volumeTabStatesOnCurrentPage
                
                guard let info = env.mangaClient.getDidReadChapterOnPaginationPage(chapterIndex, volumes) else {
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
