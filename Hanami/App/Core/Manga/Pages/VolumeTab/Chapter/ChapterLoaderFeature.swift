//
//  ChapterLoaderFeature.swift
//  Hanami
//
//  Created by Oleg on 06.12.22.
//

import Foundation
import class SwiftUI.UIImage
import ComposableArchitecture

struct ChapterLoaderFeature: ReducerProtocol {
    struct State: Equatable {
        let parentManga: Manga
        let online: Bool
        
        var cachedChaptersStates = Set<CachedChapterState>()
        
        var useHighResImagesForCaching: Bool?
    }
    
    struct CachedChapterState: Equatable, Hashable, Identifiable {
        let id: UUID
        let status: Status
        let pagesCount: Int
        let pagesFetched: Int
        
        enum Status {
            case cached, downloadInProgress, downloadFailed
        }
    }
    
    enum Action: Equatable {
        case chapterDeletionConfirmed(chapterID: UUID)
        
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        
        case downloadChapterButtonTapped(chapter: ChapterDetails)
        case chapterPageForCachingFetched(Result<UIImage, AppError>, pageIndex: Int, ChapterDetails)
        case pagesInfoForChapterCachingFetched(Result<ChapterPagesInfo, AppError>, ChapterDetails)
        
        case retrieveCachedChaptersFromMemory
        case savedInMemoryChaptersRetrieved(Result<Set<UUID>, AppError>)
        case allChapterDetailsRetrievedFromDisk(Result<[CoreDataChapterDetailsEntry], AppError>)
    }
    
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.mainQueue) private var mainQueue

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        struct CancelChapterCache: Hashable { let id: UUID }
        
        switch action {
        case .retrieveCachedChaptersFromMemory:
            return cacheClient
                .retrieveFromMemoryCachedChapters(state.parentManga.id)
                .receive(on: mainQueue)
                .catchToEffect(Action.savedInMemoryChaptersRetrieved)
            
        case .savedInMemoryChaptersRetrieved(let result):
            switch result {
            case .success(let cachedChapterIDs):
                state.cachedChaptersStates.removeAll(where: { !cachedChapterIDs.contains($0.id) && $0.status == .cached })
                for cID in cachedChapterIDs where !state.cachedChaptersStates.contains(where: { $0.id == cID }) {
                    // have to check, because this state also contains chapters, whose download process is in progress
                    state.cachedChaptersStates.insertOrUpdateByID(
                        .init(id: cID, status: .cached, pagesCount: 0, pagesFetched: 0)
                    )
                }
                
                return .none
                
            case .failure(let error):
                logger.info(
                    "Failed to fetch all chapterDetails: \(error)",
                    context: ["mangaID": "\(state.parentManga.id.uuidString.lowercased())"]
                )
                return databaseClient
                    .retrieveAllChaptersForManga(mangaID: state.parentManga.id)
                    .catchToEffect(Action.allChapterDetailsRetrievedFromDisk)
            }
            
        case .allChapterDetailsRetrievedFromDisk(let result):
            // only to store all cached on device chapter ids(from parent manga)
            // and update state on scroll as less as possible
            switch result {
            case .success(let chapterEntries):
                state.cachedChaptersStates.removeAll(where: { $0.status == .cached })
                let cachedChapterIDs = Set(chapterEntries.map(\.chapter.id))
                
                for cachedChapterID in cachedChapterIDs {
                    state.cachedChaptersStates.insertOrUpdateByID(
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
            
        case .chapterDeletionConfirmed(let chapterID):
            state.cachedChaptersStates.removeAll(where: { $0.id == chapterID })
            
            var effects: [EffectTask<Action>] = [
                databaseClient
                    .deleteChapter(chapterID: chapterID)
                    .fireAndForget(),
                
                cacheClient
                    .removeCachedChapterIDFromMemory(state.parentManga.id, chapterID)
                    .fireAndForget(),
                
                .cancel(id: CancelChapterCache(id: chapterID))
            ]
            
            if let pagesCount = databaseClient.retrieveChapter(chapterID: chapterID)?.pagesCount {
                effects.append(
                    mangaClient
                        .removeCachedPagesForChapter(chapterID, pagesCount, cacheClient)
                        .fireAndForget()
                )
            }
            
            return .merge(effects)
            
        case .downloadChapterButtonTapped(let chapter):
            state.cachedChaptersStates.insertOrUpdateByID(
                .init(
                    id: chapter.id,
                    status: .downloadInProgress,
                    pagesCount: chapter.attributes.pagesCount,
                    pagesFetched: 0
                )
            )
            
            return .concatenate(
                // need to retrieve `SettingsConfig` each time, because use can update it and we have no listeners on this updates
                settingsClient.retireveSettingsConfig()
                    .receive(on: mainQueue)
                    .catchToEffect(Action.settingsConfigRetrieved),
                
                mangaClient.fetchPagesInfo(chapter.id)
                    .receive(on: mainQueue)
                    .catchToEffect { .pagesInfoForChapterCachingFetched($0, chapter) }
            )
            
        case .settingsConfigRetrieved(let result):
            switch result {
            case .success(let config):
                state.useHighResImagesForCaching = config.useHigherQualityImagesForCaching
                return .none
                
            case .failure(let error):
                logger.error("Failed to retrieve SettingsConfig: \(error)")
                return .none
            }
            
        case .pagesInfoForChapterCachingFetched(let result, let chapter):
            switch result {
            case .success(let pagesInfo):
                let pagesURLs = pagesInfo.getPagesURLs(highQuality: state.useHighResImagesForCaching ?? false)
                
                state.cachedChaptersStates.insertOrUpdateByID(
                    .init(
                        id: chapter.id,
                        status: .downloadInProgress,
                        pagesCount: pagesURLs.count,
                        pagesFetched: 0
                    )
                )
                
                var effects = pagesURLs
                    .enumerated()
                    .map { i, url in
                        imageClient
                            .downloadImage(url)
                            .receive(on: mainQueue)
                            .eraseToEffect {
                                Action.chapterPageForCachingFetched($0, pageIndex: i, chapter)
                            }
                    }
                
                effects.append(
                    databaseClient.saveChapterDetails(
                        chapter,
                        pagesCount: pagesURLs.count,
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
                
                state.cachedChaptersStates.insertOrUpdateByID(
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
                
                state.cachedChaptersStates.insertOrUpdateByID(
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
                
                let msg: String
                
                if let chapterIndex = chapter.attributes.index?.clean() {
                    msg = "Failed to cache chapter \(chapterIndex) \(chapter.chapterName)\n\(error.description)"
                } else {
                    msg = "Failed to cache chapter \(chapter.chapterName)\n\(error.description)"
                }
                
                hudClient.show(message: msg)
                
                var effects: [EffectTask<Action>] = [
                    databaseClient
                        .deleteChapter(chapterID: chapter.id)
                        .fireAndForget(),
                    
                    .cancel(id: CancelChapterCache(id: chapter.id))
                ]
                
                state.cachedChaptersStates.insertOrUpdateByID(
                    .init(
                        id: chapter.id,
                        status: .downloadFailed,
                        pagesCount: 1,
                        pagesFetched: 0
                    )
                )
                
                if let pagesCount = databaseClient.retrieveChapter(chapterID: chapter.id)?.pagesCount {
                    effects.append(
                        mangaClient.removeCachedPagesForChapter(chapter.id, pagesCount, cacheClient).fireAndForget()
                    )
                }
                
                return .merge(effects)
            }
        }
    }
}
