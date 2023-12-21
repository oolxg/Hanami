//
//  ChapterLoaderFeature.swift
//  Hanami
//
//  Created by Oleg on 06.12.22.
//

import Foundation
import class SwiftUI.UIImage
import ComposableArchitecture
import ModelKit
import Utils
import Logger
import ImageClient
import SettingsClient
import HUD
import CacheClient

struct ChapterLoaderFeature: Reducer {
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
        case chapterPageForCachingFetched(Result<UIImage, AppError>, chapter: ChapterDetails, pageIndex: Int)
        case pagesInfoForChapterCachingFetched(Result<ChapterPagesInfo, AppError>, ChapterDetails)
        
        case retrieveCachedChaptersFromMemory
        case savedInMemoryChaptersRetrieved(Result<Set<UUID>, AppError>)
        case allChapterDetailsRetrievedFromDisk(Result<[CoreDataChapterDetailsEntry], AppError>)
    }
    
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hud) private var hud
    @Dependency(\.logger) private var logger
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.mainQueue) private var mainQueue
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        struct CancelChapterCache: Hashable { let id: UUID }
        switch action {
        case .retrieveCachedChaptersFromMemory:
            let mangaID = state.parentManga.id
            return .run { send in
                let chapterIDs = try? await cacheClient.retrieveFromMemoryCachedChapters(for: mangaID)
                
                if let chapterIDs {
                    await send(.savedInMemoryChaptersRetrieved(.success(chapterIDs)))
                } else {
                    await send(.savedInMemoryChaptersRetrieved(.failure(.notFound)))
                }
            }
            
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
                
                return .run { [mangaID = state.parentManga.id] send in
                    let cachedChaptersResult = await databaseClient.retrieveChaptersForManga(mangaID: mangaID)
                    await send(.allChapterDetailsRetrievedFromDisk(cachedChaptersResult))
                }
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
                
                cacheClient.replaceCachedChaptersInMemory(mangaID: state.parentManga.id, chapterIDs: cachedChapterIDs)
                
                return .none
                
            case .failure(let error):
                logger.info(
                    "Failed to fetch all cached chapters for manga: \(error)",
                    context: ["mangaID": "\(state.parentManga.id.uuidString.lowercased())"]
                )
                return .none
            }
            
        case .chapterDeletionConfirmed(let chapterID):
            state.cachedChaptersStates.removeAll(where: { $0.id == chapterID })
            
            cacheClient.removeCachedChapterIDFromMemory(for: state.parentManga.id, chapterID: chapterID)
            
            if let pagesCount = databaseClient.retrieveChapter(chapterID: chapterID)?.pagesCount {
                mangaClient.removeCachedPagesForChapter(chapterID, pagesCount: pagesCount)
            }
            
            databaseClient
                .deleteChapter(chapterID: chapterID)
            
            return .cancel(id: CancelChapterCache(id: chapterID))
            
        case .downloadChapterButtonTapped(let chapter):
            state.cachedChaptersStates.insertOrUpdateByID(
                .init(
                    id: chapter.id,
                    status: .downloadInProgress,
                    pagesCount: chapter.attributes.pagesCount,
                    pagesFetched: 0
                )
            )
            
            // need to retrieve `SettingsConfig` each time, because user can update it and we have no listeners on this updates
            return .run { send in
                    let settingsConfigResult = await settingsClient.retireveSettingsConfig()
                    await send(.settingsConfigRetrieved(settingsConfigResult))
                    
                    let pagesInfoResult = await mangaClient.fetchPagesInfo(for: chapter.id)
                    await send(.pagesInfoForChapterCachingFetched(pagesInfoResult, chapter))
                }
            
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
                
                databaseClient.saveChapterDetails(
                    chapter,
                    pagesCount: pagesURLs.count,
                    parentManga: state.parentManga
                )

                
                return .run { send in
                    for (i, pageURL) in pagesURLs.enumerated() {
                        let result = await imageClient.downloadImage(from: pageURL)
                        await send(
                            .chapterPageForCachingFetched(
                                result,
                                chapter: chapter,
                                pageIndex: i
                            )
                        )
                    }
                }
                .cancellable(id: CancelChapterCache(id: chapter.id))
                
            case .failure(let error):
                logger.error(
                    "Failed to fetch pagesInfo for caching: \(error)",
                    context: [
                        "mangaID": "\(state.parentManga.id.uuidString.lowercased())",
                        "chapterID": "\(chapter.id.uuidString.lowercased())"
                    ]
                )
                
                hud.show(message: "Failed to cache chapter \(chapter.chapterName)")
                
                state.cachedChaptersStates.insertOrUpdateByID(
                    .init(
                        id: chapter.id,
                        status: .downloadFailed,
                        pagesCount: 1,
                        pagesFetched: 0
                    )
                )
                
                databaseClient
                    .deleteChapter(chapterID: chapter.id)
                
                return .cancel(id: CancelChapterCache(id: chapter.id))
            }
            
            
        case .chapterPageForCachingFetched(.success(let chapterPage), let chapter, let pageIndex):
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
            
            cacheClient.saveCachedChapterInMemory(mangaID: state.parentManga.id, chapterID: chapter.id)
            mangaClient.saveChapterPage(chapterPage, withIndex: pageIndex, chapterID: chapter.id)
            
            return .none
            
        case .chapterPageForCachingFetched(.failure(let error), let chapter, let pageIndex):
            logger.error(
                "Failed to fetch page for caching: \(error)",
                context: [
                    "mangaID": "\(state.parentManga.id.uuidString.lowercased())",
                    "chapterID": "\(chapter.id.uuidString.lowercased())",
                    "pageIndex": "\(pageIndex)"
                ]
            )
            
            let msg = if let chapterIndex = chapter.attributes.index?.clean() {
                "Failed to cache chapter \(chapterIndex) \(chapter.chapterName)\n\(error.description)"
            } else {
                "Failed to cache chapter \(chapter.chapterName)\n\(error.description)"
            }
            
            hud.show(message: msg)
            
            state.cachedChaptersStates.insertOrUpdateByID(
                .init(
                    id: chapter.id,
                    status: .downloadFailed,
                    pagesCount: 1,
                    pagesFetched: 0
                )
            )
            
            if let pagesCount = databaseClient.retrieveChapter(chapterID: chapter.id)?.pagesCount {
                mangaClient.removeCachedPagesForChapter(chapter.id, pagesCount: pagesCount)
            }
            
            databaseClient.deleteChapter(chapterID: chapter.id)
            
            return .cancel(id: CancelChapterCache(id: chapter.id))
        }
    }
}
