//
//  ChapterFeature.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct ChapterState: Equatable, Identifiable {
    // Chapter basic info
    let chapter: Chapter
    let isOnline: Bool
    let parentManga: Manga
    
    init(chapter: Chapter, parentManga: Manga, isOnline: Bool = false) {
        self.chapter = chapter
        self.isOnline = isOnline
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
                       let lhsScanlationGroup = lhs.scanlationGroup, let rhsScanlationGroup = rhs.scanlationGroup {
                        return lhsScanlationGroup.name < rhsScanlationGroup.name
                    }
                    
                    return lhs.attributes.translatedLanguage < rhs.attributes.translatedLanguage
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
    
    @BindableState var areChaptersShown = false
    
    var confirmationDialog: ConfirmationDialogState<ChapterAction>?
    
    var cachedChaptersStates = Set<CachedChapterState>()

    struct CachedChapterState: Equatable, Hashable {
        let chapterID: UUID
        let status: Status
        let pagesCount: Int
        let pagesFetched: Int
        
        enum Status {
            case cached, downloadInProgress, downloadFailed
        }
    }
    
    // for online reading
    struct CancelChapterFetch: Hashable { let id: UUID }
}

enum ChapterAction: BindableAction, Equatable {
    case fetchChapterDetailsIfNeeded
    case userTappedOnChapterDetails(chapter: ChapterDetails)
    case chapterDetailsFetched(result: Result<Response<ChapterDetails>, AppError>)
    case scanlationGroupInfoFetched(result: Result<Response<ScanlationGroup>, AppError>, chapterID: UUID)
    
    case checkIfChaptersCached
    case checkChapterCachedResponse(Set<ChapterState.CachedChapterState>)
    case downloadChapterForOfflineReading(chapter: ChapterDetails)
    case pagesInfoForChapterCachingFetched(Result<ChapterPagesInfo, AppError>, ChapterDetails)
    case chapterPageForCachingFetched(Result<UIImage, AppError>, pageIndex: Int, ChapterDetails)
    case cancelChapterDownload(chapterID: UUID)
    
    case deleteChapter(chapterID: UUID)
    case chapterDeletionConfirmed(chapterID: UUID)
    case cancelTapped

    case binding(BindingAction<ChapterState>)
}

struct ChapterEnvironment {
    let databaseClient: DatabaseClient
    let imageClient: ImageClient
    let cacheClient: CacheClient
    let mangaClient: MangaClient
    let hudClient: HUDClient
}

let chapterReducer = Reducer<ChapterState, ChapterAction, ChapterEnvironment> { state, action, env in
    // for caching actions
    struct CancelChapterCache: Hashable { let id: UUID }
    
    switch action {
        case .fetchChapterDetailsIfNeeded:
            var effects: [Effect<ChapterAction, Never>] = []
            
            let allChapterIDs = [state.chapter.id] + state.chapter.others
            
            for chapterID in allChapterIDs {
                let possiblyCachedChapterDetails = env.databaseClient.fetchChapter(chapterID: chapterID)
                
                if state.chapterDetailsList[id: chapterID] == nil {
                    // if chapter is cached - no need to fetch it from API
                    if let cachedChapterDetails = possiblyCachedChapterDetails?.chapter {
                        if !state._chapterDetailsList.contains(where: { $0.id == chapterID }) {
                            state._chapterDetailsList.append(cachedChapterDetails)
                        }
                        
                        state.cachedChaptersStates.insert(
                            .init(
                                chapterID: chapterID,
                                status: .cached,
                                pagesCount: possiblyCachedChapterDetails!.pagesCount,
                                pagesFetched: possiblyCachedChapterDetails!.pagesCount
                            )
                        )
                        
                        if let scanlationGroup = cachedChapterDetails.scanlationGroup {
                            state.scanlationGroups[cachedChapterDetails.id] = scanlationGroup
                        } else if let scanlationGroupID = cachedChapterDetails.scanlationGroupID {
                            effects.append(
                                env.mangaClient.fetchScanlationGroup(scanlationGroupID)
                                    .receive(on: DispatchQueue.main)
                                    .catchToEffect {
                                        ChapterAction.scanlationGroupInfoFetched(
                                            result: $0,
                                            chapterID: cachedChapterDetails.id
                                        )
                                    }
                                    .cancellable(
                                        id: ChapterState.CancelChapterFetch(id: chapterID),
                                        cancelInFlight: true
                                    )
                            )
                        }
                    } else {
                        // chapter is not cached, need to fetch
                        effects.append(
                            env.mangaClient.fetchChapterDetails(chapterID)
                                .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                                .receive(on: DispatchQueue.main)
                                .catchToEffect(ChapterAction.chapterDetailsFetched)
                                .animation(.linear)
                                .cancellable(
                                    id: ChapterState.CancelChapterFetch(id: chapterID),
                                    cancelInFlight: true
                                )
                        )
                    }
                } else if possiblyCachedChapterDetails == nil {
                    // chapter fetched, but not cached
                    if let i = state.cachedChaptersStates.firstIndex(
                        where: { $0.chapterID == chapterID && $0.status != .downloadFailed }
                    ) {
                        state.cachedChaptersStates.remove(at: i)
                    }
                }
            }
            
            state.areChaptersShown.toggle()
            
            // all effects here are online, so is this store is using in offline mode
            // e.g. OfflineMangaStore->PagesStore->...->ChapterStore
            // we should fetch nothing 
            guard state.isOnline else { return .none }
            
            return .merge(effects)
            
        case .deleteChapter(let chapterID):
            state.confirmationDialog = ConfirmationDialogState(
                title: TextState("Delete this chapter from device?"),
                message: TextState("Delete this chapter from device?"),
                buttons: [
                    .destructive(TextState("Delete"), action: .send(.chapterDeletionConfirmed(chapterID: chapterID))),
                    .cancel(TextState("Cancel"), action: .send(.cancelTapped))
                ]
            )
            
            // this cancel for the case, when action was called from '.cancelChapterDownload'
            return .cancel(id: CancelChapterCache(id: chapterID))
            
        case .chapterDeletionConfirmed(let chapterID):
            if let i = state.cachedChaptersStates.firstIndex(where: { $0.chapterID == chapterID }) {
                state.cachedChaptersStates.remove(at: i)
            }

            state.confirmationDialog = nil
            
            var effects: [Effect<ChapterAction, Never>] = [
                env.databaseClient
                    .deleteChapter(chapterID: chapterID)
                    .fireAndForget()
            ]
            
            effects.append(
                .cancel(id: CancelChapterCache(id: chapterID))
            )
            
            if let pagesCount = env.databaseClient.fetchChapter(chapterID: chapterID)?.pagesCount {
                effects.append(
                    env.mangaClient
                        .removeCachedPagesForChapter(chapterID, pagesCount, env.cacheClient)
                        .fireAndForget()
                )
            }
            
            return .merge(effects)
            
        case .cancelTapped:
            state.confirmationDialog = nil
            return .none
            
        case .userTappedOnChapterDetails:
            return .none

        case .chapterDetailsFetched(let result):
            switch result {
                case .success(let response):
                    let chapter = response.data
                    
                    state._chapterDetailsList.append(chapter)
                    
                    if let scanlationGroup = response.data.scanlationGroup {
                        state.scanlationGroups[chapter.id] = scanlationGroup
                        return .none
                    }
                    
                    guard let scanlationGroupID = chapter.scanlationGroupID else {
                        return .none
                    }
                    
                    return env.mangaClient.fetchScanlationGroup(scanlationGroupID)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect {
                            ChapterAction.scanlationGroupInfoFetched(
                                result: $0,
                                chapterID: chapter.id
                            )
                        }
                        .cancellable(
                            id: ChapterState.CancelChapterFetch(id: response.data.id),
                            cancelInFlight: true
                        )
                    
                case .failure(let error):
                    print("error on downloading chapter details, \(error)")
                    return .none
            }
            
        case .scanlationGroupInfoFetched(let result, let chapterID):
            switch result {
                case .success(let response):
                    state.scanlationGroups[chapterID] = response.data
                    return .none
                    
                case .failure(let error):
                    print("Error on fetching scanlation group \(error)")
                    return .none
            }
        // MARK: - Caching
        case .checkIfChaptersCached:
            return .task(priority: .background) { [chapter = state.chapter] in
                let allChapterIDs = [chapter.id] + chapter.others
                var cachedChaptersStates: Set<ChapterState.CachedChapterState> = []
                
                for chapterID in allChapterIDs {
                    let possiblyCacheChapter = env.databaseClient.fetchChapter(chapterID: chapterID)
                    
                    if let cachedChapter = possiblyCacheChapter {
                        cachedChaptersStates.insert(
                            .init(
                                chapterID: cachedChapter.chapter.id,
                                status: .cached,
                                pagesCount: cachedChapter.pagesCount,
                                pagesFetched: cachedChapter.pagesCount
                            )
                        )
                    }
                }
                
                return .checkChapterCachedResponse(cachedChaptersStates)
            }
            
        case .checkChapterCachedResponse(let cachedChaptersStates):
            let failedToDownloadChapters = state.cachedChaptersStates.filter { $0.status == .downloadFailed }
            state.cachedChaptersStates = cachedChaptersStates.union(failedToDownloadChapters)
            return .none
            
        case .downloadChapterForOfflineReading(let chapter):
            if let i = state.cachedChaptersStates.firstIndex(where: { $0.chapterID == chapter.id }) {
                state.cachedChaptersStates.remove(at: i)
            }
            
            state.cachedChaptersStates.insert(
                .init(
                    chapterID: chapter.id,
                    status: .downloadInProgress,
                    pagesCount: 0,
                    pagesFetched: 0
                )
            )
            
            var effects: [Effect<ChapterAction, Never>] = [
                env.mangaClient.fetchPagesInfo(chapter.id)
                    .receive(on: DispatchQueue.main)
                    .catchToEffect { .pagesInfoForChapterCachingFetched($0, chapter) }
            ]
            
            return .merge(effects)
            
        case .pagesInfoForChapterCachingFetched(let result, let chapter):
            switch result {
                case .success(let pagesInfo):
                    let chapterState = state.cachedChaptersStates.first(where: { $0.chapterID == chapter.id })!
                    state.cachedChaptersStates.remove(chapterState)
                    state.cachedChaptersStates.insert(
                        .init(
                            chapterID: chapter.id,
                            status: .downloadInProgress,
                            pagesCount: pagesInfo.dataSaverURLs.count,
                            pagesFetched: 0
                        )
                    )
                    
                    var effects = pagesInfo
                        .dataSaverURLs
                        .enumerated()
                        .map { i, url in
                            env.imageClient
                                .downloadImage(url, nil)
                                .eraseToEffect {
                                    ChapterAction.chapterPageForCachingFetched($0, pageIndex: i, chapter)
                                }
                        }
                    
                    effects.append(
                        env.databaseClient
                            .saveChapterDetails(
                                chapter,
                                pagesCount: pagesInfo.dataSaverURLs.count,
                                fromManga: state.parentManga
                            )
                            .fireAndForget()
                    )
                    
                    return .merge(effects)
                        .cancellable(id: CancelChapterCache(id: chapter.id))
                    
                case .failure(let error):
                    print("Error on fetching PagesInfo for caching: \(error)")

                    env.hudClient.show(message: "Failed to cache chapter \(chapter.chapterName)")

                    let chapterState = state.cachedChaptersStates.first(where: { $0.chapterID == chapter.id })!
                    state.cachedChaptersStates.remove(chapterState)
                    state.cachedChaptersStates.insert(
                        .init(
                            chapterID: chapter.id,
                            status: .downloadFailed,
                            pagesCount: -1,
                            pagesFetched: -1
                        )
                    )
                    
                    return .merge(
                        .cancel(id: CancelChapterCache(id: chapter.id)),
                        
                        env.databaseClient
                            .deleteChapter(chapterID: chapter.id)
                            .fireAndForget()
                    )
            }
            
            
        case .chapterPageForCachingFetched(let result, let pageIndex, let chapter):
            switch result {
                case .success(let chapterPage):
                    let chapterState = state.cachedChaptersStates.first(where: { $0.chapterID == chapter.id })!
                    state.cachedChaptersStates.remove(chapterState)
                    
                    let chapterPagesCount = chapterState.pagesCount
                    let fetchedPagesCount = chapterState.pagesFetched + 1
                    
                    state.cachedChaptersStates.insert(
                        .init(
                            chapterID: chapter.id,
                            status: fetchedPagesCount == chapterPagesCount ? .cached : .downloadInProgress,
                            pagesCount: chapterPagesCount,
                            pagesFetched: fetchedPagesCount
                        )
                    )
                    
                    return env.mangaClient
                        .saveChapterPage(chapterPage, pageIndex, chapter.id, env.cacheClient)
                        .cancellable(id: CancelChapterCache(id: chapter.id))
                        .fireAndForget()
                    
                case .failure(let error):
                    print("Error on fetching chapterPage(image) for caching: \(error.localizedDescription)")
                    
                    env.hudClient.show(message: "Failed to cache chapter \(chapter.chapterName)")
                    
                    let chapterState = state.cachedChaptersStates.first(where: { $0.chapterID == chapter.id })!
                    state.cachedChaptersStates.remove(chapterState)
                    
                    var effects: [Effect<ChapterAction, Never>] = [
                        env.databaseClient
                            .deleteChapter(chapterID: chapter.id)
                            .fireAndForget(),
                        
                        .cancel(id: CancelChapterCache(id: chapter.id))
                    ]
                    
                    state.cachedChaptersStates.insert(
                        .init(
                            chapterID: chapter.id,
                            status: .downloadFailed,
                            pagesCount: -1,
                            pagesFetched: -1
                        )
                    )
                    
                    if let pagesCount = env.databaseClient.fetchChapter(chapterID: chapter.id)?.pagesCount {
                        effects.append(
                            env.mangaClient
                                .removeCachedPagesForChapter(chapter.id, pagesCount, env.cacheClient)
                                .fireAndForget()
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
            
        case .binding:
            return .none
    }
}
.binding()
