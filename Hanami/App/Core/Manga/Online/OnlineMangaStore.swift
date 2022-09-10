//
//  MangaFeature.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

struct OnlineMangaViewState: Equatable {
    let manga: Manga
    var pagesState: PagesState?
    
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
    var mangaReadingViewState: MangaReadingViewState?
     
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
    
    case cacheAction(CacheActions)
    
    // MARK: - Substate actions
    case mangaReadingViewAction(MangaReadingViewAction)
    case pagesAction(PagesAction)
    
    // MARK: - Binding
    case binding(BindingAction<OnlineMangaViewState>)
    
    // MARK: - Actions for saving chapters for offline reading
    enum CacheActions {
        case pagesInfoForChapterCachingFetched(Result<ChapterPagesInfo, AppError>, ChapterDetails)
        case chapterPageForCachingFetched(Result<UIImage, Error>, Int, ChapterDetails)
        case coverArtFetched(Result<UIImage, Error>)
    }
}

struct MangaViewEnvironment {
    let databaseClient: DatabaseClient
    let hapticClient: HapticClient
    let cacheClient: CacheClient
    let imageClient: ImageClient
    let mangaClient: MangaClient
    let hudClient: HUDClient
}

let onlineMangaViewReducer: Reducer<OnlineMangaViewState, OnlineMangaViewAction, MangaViewEnvironment> = .combine(
    pagesReducer.optional().pullback(
        state: \.pagesState,
        action: /OnlineMangaViewAction.pagesAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            mangaClient: $0.mangaClient,
            cacheClient: $0.cacheClient
        ) }
    ),
    mangaReadingViewReducer.optional().pullback(
        state: \.mangaReadingViewState,
        action: /OnlineMangaViewAction.mangaReadingViewAction,
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
                
                return .merge(effects)
                
            case .volumesDownloaded(let result):
                switch result {
                    case .success(let response):
                        state.pagesState = PagesState(
                            mangaVolumes: response.volumes,
                            chaptersPerPage: 15,
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
                
            case .cacheAction:
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
                        .catchToEffect { .cacheAction(.pagesInfoForChapterCachingFetched($0, chapter)) }
                ]
                
                // check if we already loaded this manga and if yes, means cover art is cached already, so we don't do it again
                if !env.mangaClient.isCoverArtCached(state.manga.id, env.cacheClient), let coverArtURL = state.mainCoverArtURL {
                    effects.append(
                        env.imageClient.downloadImage(coverArtURL, nil)
                            .receive(on: DispatchQueue.main)
                            .eraseToEffect { .cacheAction(.coverArtFetched($0)) }
                    )
                }
                
                return .merge(effects)
                
            case .cacheAction(.pagesInfoForChapterCachingFetched(let result, let chapter)):
                switch result {
                    case .success(let pagesInfo):
                        var effects = pagesInfo
                            .dataSaverURLs
                            .enumerated()
                            .map { i, url in
                                env.imageClient
                                    .downloadImage(url, nil)
                                    .eraseToEffect {
                                        OnlineMangaViewAction.cacheAction(.chapterPageForCachingFetched($0, i, chapter))
                                    }
                            }
                        
                        effects.append(
                            env.databaseClient
                                .saveChapterDetails(
                                    chapter,
                                    pagesCount: pagesInfo.dataSaverURLs.count,
                                    fromManga: state.manga
                                )
                                .fireAndForget()
                        )
                        
                        return .merge(effects)
                            .cancellable(id: ChapterState.CancelChapterCache(id: chapter.id))
                        
                    case .failure(let error):
                        print("Error on fetching PagesInfo for caching: \(error)")
                        return .none
                }
                
            case .cacheAction(.coverArtFetched(let result)):
                switch result {
                    case .success(let coverArt):
                        return env.mangaClient
                            .saveCoverArt(coverArt, state.manga.id, env.cacheClient)
                            .fireAndForget()
                        
                    case .failure(let error):
                        print("Error on fetching coverArt for caching: \(error.localizedDescription)")
                        return .none
                }
                
            case .cacheAction(.chapterPageForCachingFetched(let result, let pageIndex, let chapter)):
                switch result {
                    case .success(let chapterPage):
                        return env.mangaClient
                            .saveChapterPage(chapterPage, pageIndex, chapter.id, env.cacheClient)
                            .cancellable(id: ChapterState.CancelChapterCache(id: chapter.id))
                            .fireAndForget()
                        
                    case .failure(let error):
                        env.hudClient.show(
                            message: "Failed to fetch page \(pageIndex) for chapter \(chapter.chapterName)"
                        )
                        print("Error on fetching chapterPage(image) for caching: \(error.localizedDescription)")
                        return .none
                }
                
            default:
                return .none
        }
    },
    // MARK: - Actions to read chapter
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
                
                state.isUserOnReadingView = true

                return .task { .mangaReadingViewAction(.online(.userStartedReadingChapter)) }
                
            case .mangaReadingViewAction(.online(.userStartedReadingChapter)):
                if let pageIndex = env.mangaClient.getMangaPaginationPageForReadingChapter(
                    state.mangaReadingViewState?.chapterIndex, state.pagesState!.splitIntoPagesVolumeTabStates
                ) {
                    return .task { .pagesAction(.changePage(newPageIndex: pageIndex)) }
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
