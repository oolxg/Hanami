//
//  MangaFeature.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

// swiftlint:disable:next type_body_length
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
        var lastRefreshedAt: Date?
        
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
        case mangaTabButtonTapped(Tab)
        case authorNameTapped(Author)
        case refreshButtonTapped
        
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
    @Dependency(\.openURL) private var openURL
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.logger) private var logger
    
    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                var effects: [EffectTask<Action>] = []
                
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
                    let allowHaptic = state.pagesState != nil
                    
                    if state.pagesState != nil {
                        hudClient.show(message: "Updated!", backgroundColor: .theme.green)
                    }
                    
                    let currentPageIndex = state.pagesState?.currentPageIndex
                    
                    state.pagesState = PagesFeature.State(
                        manga: state.manga,
                        mangaVolumes: response.volumes,
                        chaptersPerPage: 10,
                        online: true
                    )
                    
                    if let currentPageIndex {
                        state.pagesState?.currentPageIndex = currentPageIndex
                    }
                    
                    return allowHaptic ? hapticClient.generateNotificationFeedback(.success).fireAndForget() : .none
                    
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
                
            case .mangaTabButtonTapped(let newTab):
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
                
            case .refreshButtonTapped:
                if let lastRefreshedAt = state.lastRefreshedAt, (.now - lastRefreshedAt) < 10 {
                    hudClient.show(
                        message: "Wait a little to refresh this page",
                        iconName: "clock",
                        backgroundColor: .theme.yellow
                    )
                    return hapticClient
                        .generateNotificationFeedback(.error)
                        .fireAndForget()
                }
                
                state.lastRefreshedAt = .now
                
                return .merge(
                    mangaClient.fetchMangaChapters(state.manga.id, nil, nil)
                        .receive(on: DispatchQueue.main)
                        .delay(for: .seconds(0.7), scheduler: DispatchQueue.main)
                        .catchToEffect(Action.volumesRetrieved),
                    
                    hapticClient.generateFeedback(.medium).fireAndForget()
                )
                
            case .authorNameTapped(let author):
                state.showAuthorView = true
                
                if state.authorViewState?.authorID != author.id {
                    state.authorViewState = AuthorFeature.State(authorID: author.id)
                }
                
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
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .downloadChapterButtonTapped))):
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
                        "Failed to fetch main cover art for caching: \(error)",
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
                if let url = chapter.attributes.externalURL {
                    return .fireAndForget { await openURL(url) }
                }
                
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
                    return .task { .pagesAction(.pageIndexButtonTapped(newPageIndex: pageIndex)) }
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
