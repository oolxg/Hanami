//
//  MangaFeature.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage
@preconcurrency
import ModelKit
import Utils
import DataTypeExtensions
import Logger
import ImageClient
import SettingsClient
import HapticClient
import HomeClient

@Reducer
// swiftlint:disable:next type_body_length
struct OnlineMangaFeature {
    struct State: Equatable {
        // MARK: - Props for view
        let manga: Manga
        var pagesState: PagesFeature.State?
        
        init(manga: Manga) {
            self.manga = manga
        }
        
        var statistics: MangaStatistics?
        
        var allCoverArtsInfo: [CoverArtInfo] = []
        var selectedTab: Tab = .chapters
        var lastReadChapterID: UUID?
        
        var mainCoverArtURL: URL?
        var coverArtURL256: URL?
        var croppedCoverArtURLs: [URL] {
            allCoverArtsInfo.compactMap(\.coverArtURL512)
        }
        var isErrorOccured = false
        
        // different chapter option to start reading manga
        // swiftlint:disable:next identifier_name
        var _firstChapterOptions: [ChapterDetails]?
        var firstChapterOptions: [ChapterDetails]?
        // MARK: END Props for view
        
        // MARK: - Props for MangaReadingView
        var isMangaReadingViewPresented = false
        var mangaReadingViewState: OnlineMangaReadingFeature.State?
        // MARK: END Props for MangaReadingView
        
        // MARK: - Props for inner states/views
        var authorViewState: AuthorFeature.State?
        var showAuthorView = false
        // MARK: END Props for inner states/views
        
        // MARK: - Props for Related tab
        var relatedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var relatedMangaFetched = false
        // MARK: END Props for Related tab
        
        // MARK: - Behavior props
        var lastRefreshedAt: Date?
        // preffered lang for reading manga
        var prefferedLanguage: ISO639Language?
        // MARK: END Behavior props
    }
    
    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case info = "Info"
        case coverArt = "Art"
        case related = "Related"
        
        var id: String { rawValue }
    }
    
    // need `Sendable` in order to fix `Circular reference` compile-time error
    enum Action: Sendable {
        // MARK: - Actions to be called from view
        case onAppear
        case navigationTabButtonTapped(Tab)
        case authorNameTapped(Author)
        case refreshButtonTapped
        case continueReadingButtonTapped
        case startReadingButtonTapped
        case userTappedOnFirstChapterOption(ChapterDetails)
        case showAuthorViewValueDidChange(to: Bool)
        case nowReadingViewStateDidUpdate(to: Bool)
        case userDidTapOnMangaDEXFooter
        
        // MARK: - Actions to be called from reducer
        case volumesRetrieved(Result<VolumesContainer, AppError>)
        case lastReadChapterRetrieved(Result<UUID, AppError>)
        case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, AppError>)
        case allCoverArtsInfoFetched(Result<Response<[CoverArtInfo]>, AppError>)
        // swiftlint:disable:next identifier_name
        case chapterDetailsForReadingContinuationFetched(Result<Response<ChapterDetails>, AppError>)
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        case firstChapterOptionRetrieved(Result<Response<ChapterDetails>, AppError>)
        case allFirstChaptersRetrieved
        case relatedMangaFetched(Result<Response<[Manga]>, AppError>)
        case statisticForRelatedMangaFetched(Result<MangaStatisticsContainer, AppError>)
        
        // MARK: - Substate actions
        case mangaReadingViewAction(OnlineMangaReadingFeature.Action)
        case pagesAction(PagesFeature.Action)
        case authorViewAction(AuthorFeature.Action)
        indirect case relatedMangaAction(UUID, MangaThumbnailFeature.Action)

        // MARK: - Actions for saving chapters for offline reading
        case coverArtForCachingFetched(Result<UIImage, AppError>)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.hud) private var hud
    @Dependency(\.openURL) private var openURL
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.homeClient) private var homeClient
    @Dependency(\.logger) private var logger

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            // MARK: - Actions to be called from view
            case .onAppear:
                state.isErrorOccured = false

                let fetchAllCoverArts = state.allCoverArtsInfo.isEmpty
                let fetchPages = state.pagesState.isNil
                let fetchStatistics = state.statistics.isNil
                let fetchRelatedManga = state.relatedMangaThumbnailStates.isEmpty
                
                return .run { [manga = state.manga] send in
                    if fetchPages {
                        let result = await mangaClient.fetchChapters(forMangaWithID: manga.id)
                        await send(.volumesRetrieved(result))
                    }
                    
                    if fetchRelatedManga {
                        let result = await homeClient.fetchManga(ids: manga.relatedMangaIDs)
                        await send(.relatedMangaFetched(result))
                    }
                    
                    if fetchAllCoverArts {
                        let result = await mangaClient.fetchAllCoverArts(forManga: manga.id)
                        await send(.allCoverArtsInfoFetched(result))
                    }
                    
                    if fetchStatistics {
                        let result = await mangaClient.fetchStatistics(for: [manga.id])
                        await send(.mangaStatisticsDownloaded(result))
                    }
                    
                    let lastReadChapterResult = await databaseClient.getLastReadChapterID(mangaID: manga.id)
                    await send(.lastReadChapterRetrieved(lastReadChapterResult))
                }
                
            case .navigationTabButtonTapped(let newTab):
                state.selectedTab = newTab
                return .none
                
            case .authorNameTapped(let author):
                state.showAuthorView = true
                
                if state.authorViewState?.authorID != author.id {
                    state.authorViewState = AuthorFeature.State(authorID: author.id)
                }
                
                return .none
                
            case .refreshButtonTapped:
                if let lastRefreshedAt = state.lastRefreshedAt, (.now - lastRefreshedAt) < 10 {
                    hud.show(
                        message: "Wait a little to refresh this page",
                        iconName: "clock",
                        backgroundColor: .theme.yellow
                    )
                    
                    hapticClient.generateNotificationFeedback(style: .error)
                    
                    return .none
                }
                
                state.lastRefreshedAt = .now
                
                hapticClient.generateFeedback(style: .medium)
                    
                return .run { [mangaID = state.manga.id] send in
                    let result = await mangaClient.fetchChapters(forMangaWithID: mangaID)
                    try await Task.sleep(seconds: 0.7)
                    await send(.volumesRetrieved(result))
                }
                
            case .continueReadingButtonTapped:
                guard let chapterID = state.lastReadChapterID else { return .none }
                
                return .run { send in
                    let result = await mangaClient.fetchChapterDetails(for: chapterID)
                    await send(.chapterDetailsForReadingContinuationFetched(result))
                }
                
            // user wants to start reading manga from first chapter, have to retrieve preffered lang for reading
            case .startReadingButtonTapped:
                if let chapterLang = state.firstChapterOptions?.first?.attributes.translatedLanguage,
                   chapterLang == state.prefferedLanguage?.rawValue {
                    return .none
                }
                
                return .run { send in
                    let result = await settingsClient.retireveSettingsConfig()
                    await send(.settingsConfigRetrieved(result))
                }
                
            case .userTappedOnFirstChapterOption(let chapter):
                if let url = chapter.attributes.externalURL {
                    return .run { _ in await openURL(url) }
                }
                
                state.mangaReadingViewState = OnlineMangaReadingFeature.State(
                    manga: state.manga,
                    chapterID: chapter.id,
                    chapterIndex: chapter.attributes.index,
                    scanlationGroupID: chapter.scanlationGroupID,
                    translatedLanguage: chapter.attributes.translatedLanguage
                )
                state.isMangaReadingViewPresented = true
                
                return .run { await $0(.mangaReadingViewAction(.userStartedReadingChapter)) }
                
            case .userDidTapOnMangaDEXFooter:
                return .run { [mangaID = state.manga.id] _ in
                    await openURL(Defaults.Links.mangaDexTitleLink(mangaID: mangaID))
                }
                
            // MARK: - END Actions to be called from view
                
            case .volumesRetrieved(let result):
                switch result {
                case .success(let response):
                    let allowHaptic = state.pagesState.hasValue
                    
                    if state.pagesState.hasValue {
                        hud.show(message: "Updated!", backgroundColor: .theme.green)
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
                    
                    if allowHaptic {
                        hapticClient.generateNotificationFeedback(style: .success)
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch volumes: \(error)",
                        context: [
                            "mangaID": "\(state.manga.id.uuidString.lowercased())",
                            "mangaName": "\(state.manga.title)"
                        ]
                    )
                    
                    hud.show(message: "Failed to fetch: \(error.description)")
                    
                    state.isErrorOccured = true
                    
                    hapticClient.generateNotificationFeedback(style: .error)
                    
                    return .none
                }
                
            case .lastReadChapterRetrieved(let result):
                switch result {
                case .success(let lastReadChapterID):
                    state.lastReadChapterID = lastReadChapterID
                    return .none
                    
                case .failure:
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
                
            case .allCoverArtsInfoFetched(let result):
                switch result {
                case .success(let response):
                    state.allCoverArtsInfo = response.data
                    imageClient.prefetchImages(with: state.croppedCoverArtURLs)
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch list of cover arts: \(error)",
                        context: [
                            "mangaID": "\(state.manga.id.uuidString.lowercased())",
                            "mangaName": "\(state.manga.title)"
                        ]
                    )
                    hud.show(message: error.description)
                    return .none
                }
                
            case .chapterDetailsForReadingContinuationFetched(let result):
                switch result {
                case .success(let response):
                    let chapter = response.data
                    
                    state.mangaReadingViewState = OnlineMangaReadingFeature.State(
                        manga: state.manga,
                        chapterID: chapter.id,
                        chapterIndex: chapter.attributes.index,
                        scanlationGroupID: chapter.scanlationGroupID,
                        translatedLanguage: chapter.attributes.translatedLanguage
                    )
                    state.isMangaReadingViewPresented = true
                    
                    return .run { await $0(.mangaReadingViewAction(.userStartedReadingChapter)) }
                    
                case .failure(let error):
                    hud.show(message: "Failed to fetch chapter\n\(error.description)", backgroundColor: .red)
                    return .none
                }
                
            // after we retrieved preffered lang, have to find `first` chapters
            case .settingsConfigRetrieved(let result):
                switch result {
                case .success(let config):
                    state.prefferedLanguage = config.readingLanguage
                    
                    state._firstChapterOptions = []

                    let firstChapterOptionsIDs = state.pagesState!.firstChapterOptionsIDs
                    
                    return .run { send in
                        for chapterID in firstChapterOptionsIDs {
                            let result = await mangaClient.fetchChapterDetails(for: chapterID)
                            await send(.firstChapterOptionRetrieved(result))
                        }
                    }
                    
                case .failure(let error):
                    logger.error("Failed to retrieve settings config: \(error)")
                    state.prefferedLanguage = .en
                    return .none
                }
                
            case .firstChapterOptionRetrieved(let result):
                switch result {
                case .success(let response):
                    state._firstChapterOptions!.append(response.data)
                    
                    if state.pagesState!.firstChapterOptionsIDs.count == state._firstChapterOptions?.count {
                        return .run { await $0(.allFirstChaptersRetrieved) }
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to fetch chapter details for first chapter: \(error)")
                    return .none
                }
                
            // when all first chapters fetched, have to filter only with matched preffered lang
            // if nothing found, show all (maximum 12, because of screen size).
            // if there's only one chapter with preffered lang, automatically send user to manga reading view
            case .allFirstChaptersRetrieved:
                let prefferedLang = state.prefferedLanguage!.rawValue
                let chaptersWithSamePrefferedLang = state._firstChapterOptions!.filter {
                    $0.attributes.translatedLanguage == prefferedLang
                }
                
                if !chaptersWithSamePrefferedLang.isEmpty {
                    if chaptersWithSamePrefferedLang.ids != state.firstChapterOptions?.ids {
                        state.firstChapterOptions = chaptersWithSamePrefferedLang
                    }
                } else {
                    // showing all translations from first chapter
                    state.firstChapterOptions = state._firstChapterOptions
                }
                
                state.firstChapterOptions = Array(state.firstChapterOptions!.prefix(10))
                
                let onlyOneChapterAndLangMatches = state.firstChapterOptions?.count == 1 &&
                    state.firstChapterOptions!.first!.attributes.translatedLanguage == prefferedLang &&
                    state.firstChapterOptions!.first!.attributes.externalURL.isNil
                    
                
                if onlyOneChapterAndLangMatches {
                    let chapter = state.firstChapterOptions!.first!
                    state.mangaReadingViewState = OnlineMangaReadingFeature.State(
                        manga: state.manga,
                        chapterID: chapter.id,
                        chapterIndex: chapter.attributes.index,
                        scanlationGroupID: chapter.scanlationGroupID,
                        translatedLanguage: chapter.attributes.translatedLanguage
                    )
                    state.isMangaReadingViewPresented = true
                    
                    return .run { await $0(.mangaReadingViewAction(.userStartedReadingChapter)) }
                }
                
                return .none
                
            case .relatedMangaFetched(let result):
                switch result {
                case .success(let response):
                    state.relatedMangaThumbnailStates = response
                        .data
                        .map { .init(manga: $0) }
                        .asIdentifiedArray
                    
                    state.relatedMangaFetched = true
                    let mangaIDs = response.data.map(\.id)
                    
                    return .run { send in
                        let result = await mangaClient.fetchStatistics(for: mangaIDs)
                        await send(.statisticForRelatedMangaFetched(result))
                    }
                    
                case .failure(let error):
                    logger.error("Failed to fetch related manga to \(state.manga.title). Error: \(error)")
                    return .none
                }
                
            case .statisticForRelatedMangaFetched(let result):
                switch result {
                case .success(let response):
                    for stat in response.statistics {
                        state.relatedMangaThumbnailStates[id: stat.key]?.onlineMangaState!.statistics = stat.value
                    }
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch statistics for related manga to \(state.manga.title). Error: \(error)"
                    )
                    return .none
                }
                
            case .showAuthorViewValueDidChange(let newValue):
                state.showAuthorView = newValue
                return .none
                
            case .nowReadingViewStateDidUpdate(let newValue):
                state.isMangaReadingViewPresented = newValue
                return .none
                
            case .mangaReadingViewAction:
                return .none
                
            case .pagesAction:
                return .none
                
            case .coverArtForCachingFetched:
                return .none
                
            case .authorViewAction:
                return .none
                
            case .relatedMangaAction:
                return .none
            }
        }
        Reduce { state, action in
            switch action {
            // MARK: - hijacking download chapter actions
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .downloadChapterButtonTapped))),
                    .mangaReadingViewAction(.downloadChapterButtonTapped):
                // check if we already loaded this manga and if yes, means cover art is cached already, so we don't do it again
                if !mangaClient.isCoverArtCached(forManga: state.manga.id), let coverArtURL = state.mainCoverArtURL {
                    return .run { send in
                        let result = await imageClient.downloadImage(from: coverArtURL)
                        await send(.coverArtForCachingFetched(result))
                    }
                }
                
                return .none
                
            case .coverArtForCachingFetched(.success(let coverArt)):
                mangaClient.saveCoverArt(coverArt, from: state.manga.id)
                return .none
                
            case .coverArtForCachingFetched(.failure(let error)):
                logger.error(
                    "Failed to fetch main cover art for caching: \(error)",
                    context: [
                        "mangaID": "\(state.manga.id.uuidString.lowercased())",
                        "mangaName": "\(state.manga.title)"
                    ]
                )
                return .none
                
            default:
                return .none
            }
        }
        Reduce { state, action in
            switch action {
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userTappedOnChapterDetails(let chapter)))):
                if let url = chapter.attributes.externalURL {
                    return .run { _ in await openURL(url) }
                }
                
                state.mangaReadingViewState = OnlineMangaReadingFeature.State(
                    manga: state.manga,
                    chapterID: chapter.id,
                    chapterIndex: chapter.attributes.index,
                    scanlationGroupID: chapter.scanlationGroupID,
                    translatedLanguage: chapter.attributes.translatedLanguage
                )
                state.isMangaReadingViewPresented = true
                
                return .run { await $0(.mangaReadingViewAction(.userStartedReadingChapter)) }
                
            case .mangaReadingViewAction(.userStartedReadingChapter):
                let chapterIndex = state.mangaReadingViewState?.chapterIndex
                let volumes = state.pagesState!.splitIntoPagesVolumeTabStates
                
                databaseClient.setLastReadChapterID(
                    for: state.manga,
                    chapterID: state.mangaReadingViewState!.chapterID
                )
                
                var pageIndex: Int?
                
                for (i, page) in volumes.enumerated() {
                    for volumeState in page {
                        // swiftlint:disable:next for_where
                        if volumeState.chapterStates.first(where: { $0.chapter.index == chapterIndex }).hasValue {
                            pageIndex = i
                        }
                    }
                }
                
                if let pageIndex {
                    return .run { await $0(.pagesAction(.pageIndexButtonTapped(newPageIndex: pageIndex))) }
                }
                
                return .none
                
                
            case .mangaReadingViewAction(.userLeftMangaReadingView):
                defer { state.isMangaReadingViewPresented = false }
                
                state.lastReadChapterID = state.mangaReadingViewState?.chapterID
                
                let chapterIndex = state.mangaReadingViewState!.chapterIndex
                let volumes = state.pagesState!.volumeTabStatesOnCurrentPage
                
                var info: (volumeID: UUID, chapterID: UUID)?
                
                for volumeStateID in volumes.ids {
                    for chapterStateID in volumes[id: volumeStateID]!.chapterStates.ids {
                        let chapterState = volumes[id: volumeStateID]!.chapterStates[id: chapterStateID]!
                        
                        if chapterState.chapter.index == chapterIndex {
                            info = (volumeID: volumeStateID, chapterID: chapterStateID)
                        }
                    }
                }
                
                guard let info else { return .none }
                
                if state.pagesState!
                    .volumeTabStatesOnCurrentPage[id: info.volumeID]!
                    .chapterStates[id: info.chapterID]!
                    .areChaptersShown {
                    return .none
                }
                
                return .run { send in
                    await send(
                        .pagesAction(
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
        .forEach(\.relatedMangaThumbnailStates, action: /Action.relatedMangaAction) {
            MangaThumbnailFeature()
        }
    }
}
