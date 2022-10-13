//
//  ChapterFeature.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

// swiftlint:disable:next type_body_length
struct ChapterFeature: ReducerProtocol {
    struct State: Equatable, Identifiable {
            // Chapter basic info
        let chapter: Chapter
        let online: Bool
        let parentManga: Manga
        
        init(chapter: Chapter, parentManga: Manga, online: Bool = false) {
            self.chapter = chapter
            self.online = online
            self.parentManga = parentManga
        }
        
            // we can have many 'chapterDetailsList' in one ChapterState because one chapter can be translated by different scanlation groups
        var chapterDetailsList: IdentifiedArrayOf<ChapterDetails> = []
            // '_chapterDetails' is only to accumulate all ChapterDetails and then show it at all once
            // swiftlint:disable:next identifier_name
        var _chapterDetailsList: [ChapterDetails] = [] {
            didSet {
                    // if all chapters fetched, this container is no longer needed
                    // so we put all chapterDetails in 'chapterDetailsList' and clear this one
                if _chapterDetailsList.count == chaptersCount {
                    chapterDetailsList = .init(uniqueElements: _chapterDetailsList.sorted { lhs, rhs in
                            // sort by lang and by ScanlationGroup's name
                        if lhs.attributes.translatedLanguage == rhs.attributes.translatedLanguage,
                           let lhsName = lhs.scanlationGroup?.name, let rhsName = rhs.scanlationGroup?.name {
                            return lhsName < rhsName
                        }
                        
                        if let lhsLang = lhs.attributes.translatedLanguage,
                           let rhsLang = rhs.attributes.translatedLanguage {
                            return lhsLang < rhsLang
                        }
                        
                        return false
                    })
                    
                    _chapterDetailsList = []
                }
            }
        }
        var scanlationGroups: [UUID: ScanlationGroup] = [:]
        var chaptersCount: Int {
            chapter.others.count + 1
        }
        
        var id: UUID { chapter.id }
        
        var areChaptersShown = false
        
        var confirmationDialog: ConfirmationDialogState<Action>?
        
        var cachedChaptersStates = Set<CachedChapterState>()
        struct CachedChapterState: Equatable, Hashable, Identifiable {
            let id: UUID
            let status: Status
            let pagesCount: Int
            let pagesFetched: Int
            
            enum Status {
                case cached, downloadInProgress, downloadFailed
            }
        }
    }
    
    // for online reading
    struct CancelChapterFetch: Hashable { let id: UUID }
    
    enum Action: Equatable {
        case fetchChapterDetailsIfNeeded
        // need this only for `cachedChaptersStates`
        case allChapterDetailsRetrievedFromDisk(Result<[CachedChapterEntry], AppError>)
        case userTappedOnChapterDetails(chapter: ChapterDetails)
        case chapterDetailsFetched(result: Result<Response<ChapterDetails>, AppError>)
        case scanlationGroupInfoFetched(result: Result<Response<ScanlationGroup>, AppError>, chapterID: UUID)
        
        case checkIfChaptersCached
        case savedInMemoryChaptersRetrieved(Result<Set<UUID>, AppError>)
        case downloadChapterForOfflineReading(chapter: ChapterDetails)
        case pagesInfoForChapterCachingFetched(Result<ChapterPagesInfo, AppError>, ChapterDetails)
        case chapterPageForCachingFetched(Result<UIImage, AppError>, pageIndex: Int, ChapterDetails)
        case cancelChapterDownload(chapterID: UUID)
        
        case deleteChapter(chapterID: UUID)
        case chapterDeletionConfirmed(chapterID: UUID)
        case cancelTapped
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        // for caching actions
        struct CancelChapterCache: Hashable { let id: UUID }
        
        switch action {
            case .fetchChapterDetailsIfNeeded:
                var effects: [Effect<Action, Never>] = [
                    databaseClient
                        .retrieveChaptersForManga(mangaID: state.parentManga.id)
                        .catchToEffect(Action.allChapterDetailsRetrievedFromDisk)
                ]
                
                let allChapterIDs = [state.chapter.id] + state.chapter.others
                
                for chapterID in allChapterIDs {
                    let possiblyCachedChapterEntry = databaseClient.fetchChapter(chapterID: chapterID)
                    
                    if state.chapterDetailsList[id: chapterID] == nil {
                        // if chapter is cached - no need to fetch it from API
                        if let cachedChapterDetails = possiblyCachedChapterEntry?.chapter {
                            if !state._chapterDetailsList.contains(where: { $0.id == chapterID }) {
                                state._chapterDetailsList.append(cachedChapterDetails)
                            }
                            
                            if let scanlationGroup = cachedChapterDetails.scanlationGroup {
                                state.scanlationGroups[cachedChapterDetails.id] = scanlationGroup
                            } else if state.online, let scanlationGroupID = cachedChapterDetails.scanlationGroupID {
                                effects.append(
                                    mangaClient.fetchScanlationGroup(scanlationGroupID)
                                        .receive(on: DispatchQueue.main)
                                        .catchToEffect { .scanlationGroupInfoFetched(result: $0, chapterID: chapterID) }
                                        .cancellable(
                                            id: CancelChapterFetch(id: chapterID),
                                            cancelInFlight: true
                                        )
                                )
                            }
                        } else if state.online {
                            // chapter is not cached, need to fetch
                            effects.append(
                                mangaClient.fetchChapterDetails(chapterID)
                                    .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                                    .receive(on: DispatchQueue.main)
                                    .catchToEffect(ChapterFeature.Action.chapterDetailsFetched)
                                    .animation(.linear)
                                    .cancellable(id: CancelChapterFetch(id: chapterID), cancelInFlight: true)
                            )
                        }
                    }
                }
                
                state.areChaptersShown.toggle()
                
                return .merge(effects)
                
            case .allChapterDetailsRetrievedFromDisk(let result):
                // only to store all cached on device chapter ids(from parent manga)
                // and update state on scroll as less as possible
                switch result {
                    case .success(let chaptersEntry):
                        state.cachedChaptersStates.removeAll()
                        let cachedChapterIDs = Set(chaptersEntry.map(\.chapter.id))
                        
                        for cachedChapterID in cachedChapterIDs {
                            state.cachedChaptersStates.insertOrUpdate(
                                .init(
                                    id: cachedChapterID,
                                    status: .cached,
                                    pagesCount: 0,
                                    pagesFetched: 0
                                )
                            )
                        }
                        
                        return cacheClient
                            .saveCachedChaptersInMemory(state.parentManga.id, cachedChapterIDs)
                            .fireAndForget()
                        
                    case .failure(let error):
                        logger.info(
                            "Failed to fetch all cached chapters for manga: \(error)",
                            context: ["mangaID": "\(state.parentManga.id.uuidString.lowercased())"]
                        )
                        return .none
                }
                
            case .userTappedOnChapterDetails:
                return .none
                
            case .chapterDetailsFetched(let result):
                switch result {
                    case .success(let response):
                        let chapter = response.data
                        
                        if !state._chapterDetailsList.contains(where: { $0.id == chapter.id }) {
                            state._chapterDetailsList.append(chapter)
                        }
                        
                        if let scanlationGroup = response.data.scanlationGroup {
                            state.scanlationGroups[chapter.id] = scanlationGroup
                            return .none
                        }
                        
                        guard let scanlationGroupID = chapter.scanlationGroupID else {
                            return .none
                        }
                        
                        return mangaClient.fetchScanlationGroup(scanlationGroupID)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect { .scanlationGroupInfoFetched(result: $0, chapterID: chapter.id) }
                            .cancellable(
                                id: CancelChapterFetch(id: response.data.id),
                                cancelInFlight: true
                            )
                        
                    case .failure(let error):
                        logger.error(
                            "Failed to fetch chapterDetails: \(error)",
                            context: ["mangaID": "\(state.parentManga.id.uuidString.lowercased())"]
                        )
                        return .none
                }
                
            case .scanlationGroupInfoFetched(let result, let chapterID):
                switch result {
                    case .success(let response):
                        state.scanlationGroups[chapterID] = response.data
                        return .none
                        
                    case .failure(let error):
                        logger.error(
                            "Failed to fetch scanlationGroup: \(error)",
                            context: [
                                "mangaID": "\(state.parentManga.id.uuidString.lowercased())",
                                "chapterID": "\(chapterID.uuidString.lowercased())"
                            ]
                        )
                        return .none
                }
            // MARK: - Caching
            case .deleteChapter(let chapterID):
                state.confirmationDialog = ConfirmationDialogState(
                    title: TextState("Delete this chapter from device?"),
                    message: TextState("Delete this chapter from device?"),
                    buttons: [
                        .destructive(
                            TextState("Delete"),
                            action: .send(.chapterDeletionConfirmed(chapterID: chapterID))
                        ),
                        .cancel(TextState("Cancel"), action: .send(.cancelTapped))
                    ]
                )
                
                    // this cancel for the case, when action was called from '.cancelChapterDownload'
                return .cancel(id: CancelChapterCache(id: chapterID))
                
            case .cancelTapped:
                state.confirmationDialog = nil
                return .none
                
            case .chapterDeletionConfirmed(let chapterID):
                state.confirmationDialog = nil
                
                state.cachedChaptersStates.remove(where: { $0.id == chapterID })
                
                if !state.online {
                    state.chapterDetailsList.remove(id: chapterID)
                }
                
                var effects: [Effect<Action, Never>] = [
                    databaseClient
                        .deleteChapter(chapterID: chapterID)
                        .fireAndForget(),
                    
                    cacheClient
                        .removeCachedChapterIDFromMemory(state.parentManga.id, chapterID)
                        .fireAndForget(),
                    
                    .cancel(id: CancelChapterCache(id: chapterID))
                ]
                
                if let pagesCount = databaseClient.fetchChapter(chapterID: chapterID)?.pagesCount {
                    effects.append(
                        mangaClient
                            .removeCachedPagesForChapter(chapterID, pagesCount, cacheClient)
                            .fireAndForget()
                    )
                }
                
                return .merge(effects)
                
            case .checkIfChaptersCached:
                return cacheClient
                    .retrieveFromMemoryCachedChapters(state.parentManga.id)
                    .catchToEffect(Action.savedInMemoryChaptersRetrieved)
                
            case .savedInMemoryChaptersRetrieved(let result):
                switch result {
                    case .success(let cachedChapterIDs):
                        state.cachedChaptersStates.remove(where: { !cachedChapterIDs.contains($0.id) })
                        for cachedChapterID in cachedChapterIDs {
                            // have to check, because this state also contains chapters, whose download process is in progress
                            if !state.cachedChaptersStates.contains(where: { $0.id == cachedChapterID }) {
                                state.cachedChaptersStates.insertOrUpdate(
                                    .init(
                                        id: cachedChapterID,
                                        status: .cached,
                                        pagesCount: 0,
                                        pagesFetched: 0
                                    )
                                )
                            }
                        }
                        
                        return .none
                        
                    case .failure(let error):
                        logger.info(
                            "Failed to fetch all chapterDetails: \(error)",
                            context: ["mangaID": "\(state.parentManga.id.uuidString.lowercased())"]
                        )
                        return databaseClient
                            .retrieveChaptersForManga(mangaID: state.parentManga.id)
                            .catchToEffect(Action.allChapterDetailsRetrievedFromDisk)
                }
                
            case .downloadChapterForOfflineReading(let chapter):
                state.cachedChaptersStates.insertOrUpdate(
                    .init(
                        id: chapter.id,
                        status: .downloadInProgress,
                        pagesCount: chapter.attributes.pagesCount,
                        pagesFetched: 0
                    )
                )
                
                return mangaClient.fetchPagesInfo(chapter.id)
                    .receive(on: DispatchQueue.main)
                    .catchToEffect { .pagesInfoForChapterCachingFetched($0, chapter) }
                
            case .pagesInfoForChapterCachingFetched(let result, let chapter):
                switch result {
                    case .success(let pagesInfo):
                        state.cachedChaptersStates.insertOrUpdate(
                            .init(
                                id: chapter.id,
                                status: .downloadInProgress,
                                pagesCount: pagesInfo.pagesURLs.count,
                                pagesFetched: 0
                            )
                        )
                        
                        var effects = pagesInfo
                            .pagesURLs
                            .enumerated()
                            .map { i, url in
                                imageClient
                                    .downloadImage(url)
                                    .eraseToEffect {
                                        Action.chapterPageForCachingFetched($0, pageIndex: i, chapter)
                                    }
                            }
                        
                        effects.append(
                            databaseClient
                                .saveChapterDetails(
                                    chapter,
                                    pagesCount: pagesInfo.pagesURLs.count,
                                    parentManga: state.parentManga
                                )
                                .fireAndForget()
                        )
                        
                        return .merge(effects)
                            .cancellable(id: CancelChapterCache(id: chapter.id))
                        
                    case .failure(let error):
                        logger.error(
                            "Failed to fetch pagesInfo for caching: \(error)",
                            context: [
                                "mangaID": "\(state.parentManga.id.uuidString.lowercased())",
                                "chapterID": "\(chapter.id.uuidString.lowercased())"
                            ]
                        )
                        
                        hudClient.show(message: "Failed to cache chapter \(chapter.chapterName)")
                        
                        state.cachedChaptersStates.insertOrUpdate(
                            .init(
                                id: chapter.id,
                                status: .downloadFailed,
                                pagesCount: 1,
                                pagesFetched: 0
                            )
                        )
                        
                        return .merge(
                            .cancel(id: CancelChapterCache(id: chapter.id)),
                            
                            databaseClient
                                .deleteChapter(chapterID: chapter.id)
                                .fireAndForget()
                        )
                }
                
                
            case .chapterPageForCachingFetched(let result, let pageIndex, let chapter):
                switch result {
                    case .success(let chapterPage):
                        let chapterState = state.cachedChaptersStates.first(where: { $0.id == chapter.id })!
                        
                        let chapterPagesCount = chapterState.pagesCount
                        let fetchedPagesCount = chapterState.pagesFetched + 1
                        
                        state.cachedChaptersStates.insertOrUpdate(
                            .init(
                                id: chapter.id,
                                status: fetchedPagesCount == chapterPagesCount ? .cached : .downloadInProgress,
                                pagesCount: chapterPagesCount,
                                pagesFetched: fetchedPagesCount
                            )
                        )
                        
                        return .merge(
                            mangaClient
                                .saveChapterPage(chapterPage, pageIndex, chapter.id, cacheClient)
                                .cancellable(id: CancelChapterCache(id: chapter.id))
                                .fireAndForget(),
                            
                            cacheClient
                                .saveCachedChapterInMemory(state.parentManga.id, chapter.id)
                                .fireAndForget()
                        )
                        
                    case .failure(let error):
                        logger.error(
                            "Failed to fetch page for caching: \(error)",
                            context: [
                                "mangaID": "\(state.parentManga.id.uuidString.lowercased())",
                                "chapterID": "\(chapter.id.uuidString.lowercased())",
                                "pageIndex": "\(pageIndex)"
                            ]
                        )
                        
                        var msg = ""
                        
                        if let chapterIndex = chapter.attributes.chapterIndex?.clean() {
                            msg = "Failed to cache chapter \(chapterIndex) \(chapter.chapterName)\n\(error.description)"
                        } else {
                            msg = "Failed to cache chapter \(chapter.chapterName)\n \(error.description)"
                        }
                        
                        hudClient.show(message: msg)
                        
                        var effects: [Effect<Action, Never>] = [
                            databaseClient
                                .deleteChapter(chapterID: chapter.id)
                                .fireAndForget(),
                            
                            .cancel(id: CancelChapterCache(id: chapter.id))
                        ]
                        
                        state.cachedChaptersStates.insertOrUpdate(
                            .init(
                                id: chapter.id,
                                status: .downloadFailed,
                                pagesCount: 1,
                                pagesFetched: 0
                            )
                        )
                        
                        if let pagesCount = databaseClient.fetchChapter(chapterID: chapter.id)?.pagesCount {
                            effects.append(
                                mangaClient.removeCachedPagesForChapter(chapter.id, pagesCount, cacheClient).fireAndForget()
                            )
                        }
                        
                        return .merge(effects)
                }
                
            case .cancelChapterDownload(let chapterID):
                state.confirmationDialog = ConfirmationDialogState(
                    title: TextState("Stop chapter download?"),
                    message: TextState("Stop chapter download?"),
                    buttons: [
                        .destructive(
                            TextState("Stop download"),
                            action: .send(.chapterDeletionConfirmed(chapterID: chapterID))
                        ),
                        .cancel(TextState("Cancel"), action: .send(.cancelTapped))
                    ]
                )
                
                return .none
                    // MARK: - Caching END
        }
    }
}