//
//  OfflineMangaViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/07/2022.
//

import Foundation
import ComposableArchitecture
import Utils
import ModelKit
import Logger
import HUD

struct OfflineMangaFeature: Reducer {
    struct State: Equatable {
        let manga: Manga
        var coverArtPath: URL?
        
        // to compare with cached chapters, we retrieved last time
        var lastRetrievedChapterIDs: Set<UUID> = []
        
        init(manga: Manga) {
            self.manga = manga
        }
        
        var pagesState: PagesFeature.State?
        var selectedTab: Tab = .chapters
        var lastReadChapter: CoreDataChapterDetailsEntry?
        
        // MARK: - Props for MangaReadingView
        var isMangaReadingViewPresented = false
        
        var mangaReadingViewState: OfflineMangaReadingFeature.State? {
            didSet { isMangaReadingViewPresented = mangaReadingViewState.hasValue }
        }
    }
    
    enum Tab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case info = "Info"
        
        var id: String { rawValue }
    }
    
    enum Action {
        // MARK: - Actions to be called from view
        case onAppear
        case continueReadingButtonTapped
        case deleteMangaButtonTapped
        case mangaTabButtonTapped(Tab)
        case nowReadingViewStateDidUpdate(to: Bool)

        // MARK: - Actions to be called from reducer
        case cachedChaptersRetrieved(Result<[CoreDataChapterDetailsEntry], AppError>)
        case chaptersForMangaDeletionRetrieved(Result<[CoreDataChapterDetailsEntry], AppError>)
        case lastReadChapterRetrieved(Result<UUID, AppError>)
        
        // MARK: - Substate actions
        case mangaReadingViewAction(OfflineMangaReadingFeature.Action)
        case pagesAction(PagesFeature.Action)
    }
    
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.hud) private var hud
    @Dependency(\.logger) private var logger
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [mangaID = state.manga.id] send in
                    let cachedChaptersResult = await databaseClient.retrieveChaptersForManga(mangaID: mangaID)
                    await send(.cachedChaptersRetrieved(cachedChaptersResult))
                    
                    let lastReadChapterIDResult = await databaseClient.getLastReadChapterID(mangaID: mangaID)
                    await send(.lastReadChapterRetrieved(lastReadChapterIDResult))
                }
                
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
                    state.pagesState = PagesFeature.State(
                        manga: state.manga,
                        chaptersDetailsList: chapters.map(\.chapter),
                        chaptersPerPage: 10
                    )
                    
                    cacheClient.replaceCachedChaptersInMemory(mangaID: state.manga.id, chapterIDs: chaptersIDsSet)
                    
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to retrieve chapters from disk: \(error)",
                        context: [
                            "mangaID": "\(state.manga.id.uuidString.lowercased())",
                            "mangaName": "\(state.manga.title)"
                        ]
                    )
                    return .none
                }
                
            case .lastReadChapterRetrieved(let result):
                switch result {
                case .success(let lastReadChapterID):
                    state.lastReadChapter = databaseClient.retrieveChapter(byID: lastReadChapterID)
                    return .none
                    
                case .failure:
                    return .none
                }
                
            case .continueReadingButtonTapped:
                guard let chapter = state.lastReadChapter else { return .none }
                
                state.mangaReadingViewState = OfflineMangaReadingFeature.State(
                    mangaID: state.manga.id,
                    chapter: chapter.chapter,
                    pagesCount: chapter.pagesCount,
                    startFromLastPage: false
                )
                
                return .run { await $0(.mangaReadingViewAction(.userStartedReadingChapter)) }
                
            case .mangaTabButtonTapped(let tab):
                state.selectedTab = tab
                return .none
                
            case .deleteMangaButtonTapped:
                return .run { [mangaID = state.manga.id] send in
                    let cachedChaptersResult = await databaseClient.retrieveChaptersForManga(mangaID: mangaID)
                    await send(.chaptersForMangaDeletionRetrieved(cachedChaptersResult))
                }
                
            case .chaptersForMangaDeletionRetrieved(let result):
                switch result {
                case .success(let chapters):
                    cacheClient.removeAllCachedChapterIDsFromMemory(for: state.manga.id)
                    mangaClient.deleteCoverArt(for: state.manga.id)
                    
                    for chapterEntity in chapters {
                        mangaClient.removeCachedPagesForChapter(
                            chapterEntity.chapter.id,
                            pagesCount: chapterEntity.pagesCount
                        )
                    }
                    databaseClient.deleteManga(mangaID: state.manga.id)
                    
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to retrieve chapters from disk for manga deletion: \(error)",
                        context: [
                            "mangaID": "\(state.manga.id.uuidString.lowercased())",
                            "mangaName": "\(state.manga.title)"
                        ]
                    )
                    return .none
                }
                
                
            case .pagesAction:
                return .none
                
            case .mangaReadingViewAction:
                return .none
                
            case .nowReadingViewStateDidUpdate(let newValue):
                state.isMangaReadingViewPresented = newValue
                return .none
            }
        }
        Reduce { state, action in
            switch action {
            case .pagesAction(.volumeTabAction(_, .chapterAction(_, .userTappedOnChapterDetails(let chapter)))):
                guard let retrievedChapter = databaseClient.retrieveChapter(byID: chapter.id) else {
                    hud.show(message: "😢 Error on retrieving saved chapter")
                    return .none
                }
                
                state.mangaReadingViewState = OfflineMangaReadingFeature.State(
                    mangaID: state.manga.id,
                    chapter: retrievedChapter.chapter,
                    pagesCount: retrievedChapter.pagesCount,
                    startFromLastPage: false
                )
                                
                return .run { await $0(.mangaReadingViewAction(.userStartedReadingChapter)) }
                
            case .mangaReadingViewAction(.userStartedReadingChapter):
                databaseClient.setLastReadChapterID(
                    for: state.manga,
                    chapterID: state.mangaReadingViewState!.chapter.id
                )
                
                let pages = state.pagesState!.splitIntoPagesVolumeTabStates
                let chapterIndex = state.mangaReadingViewState?.chapter.attributes.index
                var pageIndex: Int?
                
                for (i, page) in pages.enumerated() {
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
                
                state.lastReadChapter = CoreDataChapterDetailsEntry(
                    chapter: state.mangaReadingViewState!.chapter,
                    pagesCount: state.mangaReadingViewState!.pagesCount
                )
                
                let chapterIndex = state.mangaReadingViewState!.chapter.attributes.index
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
                
                // chapterState, on which user has left MangaReadingView
                let chapterState = state.pagesState!
                    .volumeTabStatesOnCurrentPage[id: info.volumeID]!
                    .chapterStates[id: info.chapterID]!
                
                if chapterState.areChaptersShown {
                    return .none
                }
                
                return ChapterFeature()
                    .reduce(
                        into: &state
                            .pagesState!
                            .volumeTabStatesOnCurrentPage[id: info.volumeID]!
                            .chapterStates[id: info.chapterID]!,
                        action: .fetchChapterDetailsIfNeeded
                    )
                    .map {
                        .pagesAction(
                            .volumeTabAction(
                                volumeID: info.volumeID,
                                volumeAction: .chapterAction(
                                    id: info.chapterID,
                                    action: $0
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
            OfflineMangaReadingFeature()
        }
    }
}
