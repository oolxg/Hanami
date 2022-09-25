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
    var mangaReadingViewState: OnlineMangaReadingViewState?
     
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
    
    // MARK: - Substate actions
    case mangaReadingViewAction(OnlineMangaReadingViewAction)
    case pagesAction(PagesAction)
    
    // MARK: - Binding
    case binding(BindingAction<OnlineMangaViewState>)
    
    // MARK: - Actions for saving chapters for offline reading
    case coverArtForCachingFetched(Result<UIImage, AppError>)
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
            imageClient: $0.imageClient,
            cacheClient: $0.cacheClient,
            mangaClient: $0.mangaClient,
            hudClient: $0.hudClient
        ) }
    ),
    onlineMangaReadingViewReducer.optional().pullback(
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
                            manga: state.manga,
                            mangaVolumes: response.volumes,
                            chaptersPerPage: 15,
                            isOnline: true
                        )
                        
                        return .none
                        
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error.description)")
                        
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
                        print("error on fetching allCoverArtsInfo, \(error.description)")
                        return .none
                }
                
            case .mangaStatisticsDownloaded(let result):
                switch result {
                    case .success(let response):
                        state.statistics = response.statistics[state.manga.id]
                        return .none
                        
                    case .failure(let error):
                        print("error on mangaFetchStatistics, \(error.description)")
                        return .none
                }
                
            case .mangaReadingViewAction:
                return .none
                
            case .pagesAction:
                return .none
                
            case .coverArtForCachingFetched:
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
                // check if we already loaded this manga and if yes, means cover art is cached already, so we don't do it again
                if !env.mangaClient.isCoverArtCached(state.manga.id, env.cacheClient), let coverArtURL = state.mainCoverArtURL {
                    return env.imageClient.downloadImage(coverArtURL)
                        .receive(on: DispatchQueue.main)
                        .eraseToEffect { .coverArtForCachingFetched($0) }
                }
                
                return .none
                
            case .coverArtForCachingFetched(let result):
                switch result {
                    case .success(let coverArt):
                        return env.mangaClient
                            .saveCoverArt(coverArt, state.manga.id, env.cacheClient)
                            .fireAndForget()
                        
                    case .failure(let error):
                        print("Error on fetching coverArt for caching: \(error.description)")
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
                state.mangaReadingViewState = OnlineMangaReadingViewState(
                    mangaID: state.manga.id,
                    chapterID: chapter.id,
                    chapterIndex: chapter.attributes.chapterIndex,
                    scanlationGroupID: chapter.scanlationGroupID,
                    translatedLanguage: chapter.attributes.translatedLanguage
                )
                
                state.isUserOnReadingView = true

                return .task { .mangaReadingViewAction(.userStartedReadingChapter) }
                
            case .mangaReadingViewAction(.userStartedReadingChapter):
                let chapterIndex = state.mangaReadingViewState?.chapterIndex
                let volumes = state.pagesState!.splitIntoPagesVolumeTabStates
                
                if let pageIndex = env.mangaClient.getMangaPageForReadingChapter(chapterIndex, volumes) {
                    return .task { .pagesAction(.changePage(newPageIndex: pageIndex)) }
                }
                
                return .none

                
            case .mangaReadingViewAction(.userLeftMangaReadingView):
                defer { state.isUserOnReadingView = false }
                
                let chapterIndex = state.mangaReadingViewState!.chapterIndex
                let volumes = state.pagesState!.volumeTabStatesOnCurrentPage
                
                guard let info = env.mangaClient.findDidReadChapterOnMangaPage(chapterIndex, volumes) else {
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
