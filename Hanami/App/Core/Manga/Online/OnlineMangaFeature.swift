//
//  MangaFeature.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

struct OnlineMangaFeature: ReducerProtocol {
    struct State: Equatable {
        let manga: Manga
        var pagesState: PagesFeature.State?
        
        init(manga: Manga) {
            self.manga = manga
        }
        
        var statistics: MangaStatistics?
        
        var allCoverArtsInfo: [CoverArtInfo] = []
        
        var selectedTab: Tab = .chapters
        // MARK: - Props for MangaReadingView
        @BindableState var isUserOnReadingView = false
        var mangaReadingViewState: OnlineMangaReadingFeature.State?
        
        var authorViewState: AuthorFeature.State?
        @BindableState var showAuthorView = false
        
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
            
            self = State(manga: manga)
            self.statistics = stat
            self.mainCoverArtURL = coverArtURL
            self.coverArtURL256 = coverArtURL256
        }
    }
    
    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case info = "Info"
        case coverArt = "Art"
        
        var id: String { rawValue }
    }
    
    struct CancelClearCache: Hashable { let mangaID: UUID }
    
    enum Action: BindableAction {
        // MARK: - Actions to be called from view
        case onAppear
        case mangaTabChanged(Tab)
        case showAuthorPage(Author)
        
        // MARK: - Actions to be called from reducer
        case volumesRetrieved(Result<VolumesContainer, AppError>)
        case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, AppError>)
        case allCoverArtsInfoFetched(Result<Response<[CoverArtInfo]>, AppError>)
        
        // MARK: - Substate actions
        case mangaReadingViewAction(OnlineMangaReadingFeature.Action)
        case pagesAction(PagesFeature.Action)
        case authorViewAction(AuthorFeature.Action)
        
        // MARK: - Binding
        case binding(BindingAction<State>)
        
        // MARK: - Actions for saving chapters for offline reading
        case coverArtForCachingFetched(Result<UIImage, AppError>)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.logger) private var logger
    
    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .onAppear:
                    var effects: [Effect<Action, Never>] = []
                    
                    if state.pagesState == nil {
                        effects.append(
                            mangaClient.fetchMangaChapters(state.manga.id, nil, nil)
                                .receive(on: DispatchQueue.main)
                                .catchToEffect(Action.volumesRetrieved)
                        )
                    }
                    
                    if state.statistics == nil {
                        effects.append(
                            mangaClient.fetchMangaStatistics(state.manga.id)
                                .receive(on: DispatchQueue.main)
                                .catchToEffect(Action.mangaStatisticsDownloaded)
                        )
                    }
                    
                    return .merge(effects)
                    
                case .volumesRetrieved(let result):
                    switch result {
                        case .success(let response):
                            state.pagesState = PagesFeature.State(
                                manga: state.manga,
                                mangaVolumes: response.volumes,
                                chaptersPerPage: 10,
                                online: true
                            )
                            
                            return .none
                            
                        case .failure(let error):
                            logger.error(
                                "Failed to fetch volumes: \(error)",
                                context: [
                                    "mangaID": "\(state.manga.id.uuidString.lowercased())",
                                    "mangaName": "\(state.manga.title)"
                                ]
                            )
                            
                            return .none
                    }
                    
                case .mangaTabChanged(let newTab):
                    state.selectedTab = newTab
                    
                    if newTab == .coverArt && state.allCoverArtsInfo.isEmpty {
                        return mangaClient.fetchAllCoverArtsForManga(state.manga.id)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(Action.allCoverArtsInfoFetched)
                    }
                    
                    return .none
                    
                case .allCoverArtsInfoFetched(let result):
                    switch result {
                        case .success(let response):
                            state.allCoverArtsInfo = response.data
                            return .none
                            
                        case .failure(let error):
                            logger.error(
                                "Failed to fetch list of cover arts: \(error)",
                                context: [
                                    "mangaID": "\(state.manga.id.uuidString.lowercased())",
                                    "mangaName": "\(state.manga.title)"
                                ]
                            )
                            hudClient.show(message: error.description)
                            return .none
                    }
                    
                case .mangaStatisticsDownloaded(let result):
                    switch result {
                        case .success(let response):
                            state.statistics = response.statistics[state.manga.id]
                            return .none
                            
                        case .failure(let error):
                            logger.error(
                                "Failed to fetch statistics for manga: \(error)",
                                context: [
                                    "mangaID": "\(state.manga.id.uuidString.lowercased())",
                                    "mangaName": "\(state.manga.title)"
                                ]
                            )
                            return .none
                    }
                    
                case .showAuthorPage(let author):
                    state.showAuthorView = true
                    state.authorViewState = AuthorFeature.State(author: author)
                    return .none
                    
                case .mangaReadingViewAction:
                    return .none
                    
                case .pagesAction:
                    return .none
                    
                case .coverArtForCachingFetched:
                    return .none
                    
                case .authorViewAction:
                    return .none
                    
                case .binding:
                    return .none
            }
        }
        Reduce { state, action in
            switch action {
                case .pagesAction(.volumeTabAction(_, .chapterAction(_, .downloadChapterForOfflineReading))):
                    // check if we already loaded this manga and if yes, means cover art is cached already, so we don't do it again
                    if !mangaClient.isCoverArtCached(state.manga.id, cacheClient), let coverArtURL = state.mainCoverArtURL {
                        return imageClient.downloadImage(coverArtURL)
                            .receive(on: DispatchQueue.main)
                            .eraseToEffect { .coverArtForCachingFetched($0) }
                    }
                    
                    return .none
                    
                case .coverArtForCachingFetched(let result):
                    switch result {
                        case .success(let coverArt):
                            return mangaClient
                                .saveCoverArt(coverArt, state.manga.id, cacheClient)
                                .fireAndForget()
                            
                        case .failure(let error):
                            logger.error(
                                "Failed to fetch main cover art for cachin: \(error)",
                                context: [
                                    "mangaID": "\(state.manga.id.uuidString.lowercased())",
                                    "mangaName": "\(state.manga.title)"
                                ]
                            )
                            return .none
                    }
                    
                default:
                    return .none
            }
        }
        Reduce { state, action in
            switch action {
                case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userTappedOnChapterDetails(let chapter)))):
                    state.mangaReadingViewState = OnlineMangaReadingFeature.State(
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
                    
                    if let pageIndex = mangaClient.getMangaPageForReadingChapter(chapterIndex, volumes) {
                        return .task { .pagesAction(.changePage(newPageIndex: pageIndex)) }
                    }
                    
                    return .none
                    
                    
                case .mangaReadingViewAction(.userLeftMangaReadingView):
                    defer { state.isUserOnReadingView = false }
                    
                    let chapterIndex = state.mangaReadingViewState!.chapterIndex
                    let volumes = state.pagesState!.volumeTabStatesOnCurrentPage
                    
                    guard let info = mangaClient.findDidReadChapterOnMangaPage(chapterIndex, volumes) else {
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
        .ifLet(\.pagesState, action: /Action.pagesAction) {
            PagesFeature()
        }
        .ifLet(\.mangaReadingViewState, action: /Action.mangaReadingViewAction) {
            OnlineMangaReadingFeature()
        }
        .ifLet(\.authorViewState, action: /Action.authorViewAction) {
            AuthorFeature()
        }
    }
}
