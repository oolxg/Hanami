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
        case chapterPageForCachingFetched(image: UIImage, chapter: ChapterDetails, pageIndex: Int)
        case didFailToFetchChapterPageForCaching(error: AppError, chapterID: UUID)
        case chapterCached
    }
    
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.logger) private var logger
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.mainQueue) private var mainQueue

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        struct CancelChapterCache: Hashable { }

        switch action {
        case .downloadChapterButtonTapped:
            if databaseClient.retrieveChapter(chapterID: state.chapterID).isNil {
                return mangaClient.fetchChapterDetails(state.chapterID)
                    .receive(on: mainQueue)
                    .catchToEffect(Action.chapterDetailsFetched)
            }
            
            return .none
            
        case .cancelDownloadButtonTapped:
            var effects: [EffectTask<Action>] = [
                databaseClient
                    .deleteChapter(chapterID: state.chapterID)
                    .fireAndForget(),
                
                cacheClient
                    .removeCachedChapterIDFromMemory(state.parentManga.id, state.chapterID)
                    .fireAndForget(),
                
                .cancel(id: CancelChapterCache())
            ]
            
            if let pagesCount = databaseClient.retrieveChapter(chapterID: state.chapterID)?.pagesCount {
                effects.append(
                    mangaClient
                        .removeCachedPagesForChapter(state.chapterID, pagesCount, cacheClient)
                        .fireAndForget()
                )
            }
            
            return .merge(effects)
                
        case .chapterDetailsFetched(let result):
            switch result {
            case .success(let response):
                let chapter = response.data
                
                return mangaClient.fetchPagesInfo(chapter.id)
                    .receive(on: mainQueue)
                    .catchToEffect { .pagesInfoForChapterCachingFetched($0, chapter: chapter) }
                
            case .failure(let error):
                logger.error("Can't fetch chapterDetails for caching in OnlineMangaViewLoaderFeature: \(error)")
                return .none
            }
            
        case .pagesInfoForChapterCachingFetched(let result, let chapter):
            switch result {
            case .success(let pagesInfo):
                let pagesURLs = pagesInfo.getPagesURLs(highQuality: state.useHighResImagesForCaching)
                state.pagesCount = pagesURLs.count
                
                return .merge(
                    .run { [chapterID = state.chapterID] send in
                        for (i, pageURL) in pagesURLs.enumerated() {
                            do {
                                let image = try await imageClient.downloadImage(from: pageURL)
                                await send(.chapterPageForCachingFetched(image: image, chapter: chapter, pageIndex: i))
                            } catch {
                                if let error = error as? AppError {
                                    await send(.didFailToFetchChapterPageForCaching(error: error, chapterID: chapter.id))
                                }
                            }
                        }
                    },
                    
                    databaseClient.saveChapterDetails(
                        chapter,
                        pagesCount: pagesURLs.count,
                        parentManga: state.parentManga
                    )
                    .fireAndForget()
                )
                .cancellable(id: CancelChapterCache())

            case .failure(let error):
                logger.error(
                    "Failed to fetch pagesInfo for caching: \(error)",
                    context: [
                        "mangaID": "\(state.parentManga.id.uuidString.lowercased())",
                        "chapterID": "\(chapter.id.uuidString.lowercased())"
                    ]
                )
                
                hudClient.show(message: "Failed to cache chapter \(chapter.chapterName)")
                
                return .merge(
                    .cancel(id: CancelChapterCache()),
                    
                    databaseClient
                        .deleteChapter(chapterID: chapter.id)
                        .fireAndForget()
                )
            }
        case .chapterPageForCachingFetched(let chapterPage, let chapter, let  pageIndex):
            state.pagesFetched += 1
            
            return .merge(
                mangaClient
                    .saveChapterPage(chapterPage, pageIndex, chapter.id, cacheClient)
                    .cancellable(id: CancelChapterCache())
                    .fireAndForget(),
                
                cacheClient
                    .saveCachedChapterInMemory(state.parentManga.id, chapter.id)
                    .fireAndForget(),
                
                state.pagesFetched == state.pagesCount ? .task { .chapterCached } : .none
            )
            
            
        case .didFailToFetchChapterPageForCaching(let error, let chapterID):
            logger.error(
                "Failed to fetch image for caching in OnlineMangaViewLoaderFeature: \(error.description)"
            )
            
            var effects: [EffectTask<Action>] = [
                databaseClient
                    .deleteChapter(chapterID: chapterID)
                    .fireAndForget(),
                
                    .cancel(id: CancelChapterCache())
            ]
            
            if let pagesCount = databaseClient.retrieveChapter(chapterID: chapterID)?.pagesCount {
                effects.append(
                    mangaClient.removeCachedPagesForChapter(chapterID, pagesCount, cacheClient).fireAndForget()
                )
            }
            
            return .merge(effects)
            
            // to be hijacked in OnlineMangaReadingViewFeature
        case .chapterCached:
            return .none
        }
    }
}
