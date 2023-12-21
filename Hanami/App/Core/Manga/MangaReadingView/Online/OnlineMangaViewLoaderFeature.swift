//
//  OnlineMangaViewLoaderFeature.swift
//  Hanami
//
//  Created by Oleg on 09.03.23.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage
import ModelKit
import Utils
import Logger
import ImageClient
import SettingsClient
import HUD

struct OnlineMangaViewLoaderFeature: Reducer {
    struct State: Equatable {
        let parentManga: Manga
        let chapterID: UUID
        let useHighResImagesForCaching: Bool
        var pagesFetched = 0
        var pagesCount: Int?
    }
    
    enum Action {
        case downloadChapterButtonTapped
        case cancelDownloadButtonTapped
        case chapterDetailsFetched(Result<Response<ChapterDetails>, AppError>)
        case pagesInfoForChapterCachingFetched(Result<ChapterPagesInfo, AppError>, chapter: ChapterDetails)
        case chapterPageForCachingFetched(Result<UIImage, AppError>, chapter: ChapterDetails, pageIndex: Int)
        case chapterCached
    }
    
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.hud) private var hud
    @Dependency(\.logger) private var logger
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.mainQueue) private var mainQueue

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        struct CancelChapterCache: Hashable { }

        switch action {
        case .downloadChapterButtonTapped:
            if databaseClient.retrieveChapter(chapterID: state.chapterID).isNil {
                return .run { [chapterID = state.chapterID] send in
                    let result = await mangaClient.fetchChapterDetails(for: chapterID)
                    await send(.chapterDetailsFetched(result))
                }
            }
            
            return .none
            
        case .cancelDownloadButtonTapped:
            cacheClient.removeCachedChapterIDFromMemory(
                for: state.parentManga.id,
                chapterID: state.chapterID
            )
            
            databaseClient.deleteChapter(chapterID: state.chapterID)
            
            if let pagesCount = databaseClient.retrieveChapter(chapterID: state.chapterID)?.pagesCount {
                mangaClient.removeCachedPagesForChapter(state.chapterID, pagesCount: pagesCount)
            }
            
            return .cancel(id: CancelChapterCache())
                
        case .chapterDetailsFetched(let result):
            switch result {
            case .success(let response):
                let chapter = response.data
                
                return .run { send in
                    let result = await mangaClient.fetchPagesInfo(for: chapter.id)
                    await send(.pagesInfoForChapterCachingFetched(result, chapter: chapter))
                }
                
            case .failure(let error):
                logger.error("Can't fetch chapterDetails for caching in OnlineMangaViewLoaderFeature: \(error)")
                return .none
            }
            
        case .pagesInfoForChapterCachingFetched(let result, let chapter):
            switch result {
            case .success(let pagesInfo):
                let pagesURLs = pagesInfo.getPagesURLs(highQuality: state.useHighResImagesForCaching)
                state.pagesCount = pagesURLs.count
                
                databaseClient.saveChapterDetails(
                    chapter,
                    pagesCount: pagesURLs.count,
                    parentManga: state.parentManga
                )
                
                return .run { send in
                    for (i, pageURL) in pagesURLs.enumerated() {
                        let result = await imageClient.downloadImage(from: pageURL)
                        await send(.chapterPageForCachingFetched(result, chapter: chapter, pageIndex: i))
                    }
                }
                .cancellable(id: CancelChapterCache())

            case .failure(let error):
                logger.error(
                    "Failed to fetch pagesInfo for caching: \(error)",
                    context: [
                        "mangaID": "\(state.parentManga.id.uuidString.lowercased())",
                        "chapterID": "\(chapter.id.uuidString.lowercased())"
                    ]
                )
                
                hud.show(message: "Failed to cache chapter \(chapter.chapterName)")
                
                databaseClient.deleteChapter(chapterID: chapter.id)
                
                return .cancel(id: CancelChapterCache())
            }
            
        case .chapterPageForCachingFetched(.success(let chapterPage), let chapter, let pageIndex):
            state.pagesFetched += 1
            
            cacheClient.saveCachedChapterInMemory(mangaID: state.parentManga.id, chapterID: chapter.id)
            mangaClient.saveChapterPage(chapterPage, withIndex: pageIndex, chapterID: chapter.id)
            
            let pagesCount = state.pagesCount
            let pagesFetched = state.pagesFetched
            
            return .run { send in
                if pagesCount == pagesFetched {
                    await send(.chapterCached)
                }
            }
            
        case .chapterPageForCachingFetched(.failure(let error), let chapter, _):
            logger.error(
                "Failed to fetch image for caching in OnlineMangaViewLoaderFeature: \(error.description)"
            )
            
            if let pagesCount = databaseClient.retrieveChapter(chapterID: chapter.id)?.pagesCount {
                mangaClient.removeCachedPagesForChapter(chapter.id, pagesCount: pagesCount)
            }
            
            databaseClient
                .deleteChapter(chapterID: chapter.id)
            
            return .cancel(id: CancelChapterCache())
            
            // to be hijacked in OnlineMangaReadingViewFeature
        case .chapterCached:
            return .none
        }
    }
}
