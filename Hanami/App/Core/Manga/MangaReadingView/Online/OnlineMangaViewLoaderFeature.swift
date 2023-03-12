//
//  OnlineMangaViewLoaderFeature.swift
//  Hanami
//
//  Created by Oleg on 09.03.23.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

struct OnlineMangaViewLoaderFeature: ReducerProtocol {
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
                
        case let .chapterDetailsFetched(result):
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
            
        case let .pagesInfoForChapterCachingFetched(result, chapter):
            switch result {
            case .success(let pagesInfo):
                let pagesURLs = pagesInfo.getPagesURLs(highQuality: state.useHighResImagesForCaching)
                state.pagesCount = pagesURLs.count
                
                var effects = pagesURLs
                    .enumerated()
                    .map { i, url in
                        imageClient
                            .downloadImage(url)
                            .receive(on: mainQueue)
                            .eraseToEffect {
                                Action.chapterPageForCachingFetched($0, chapter: chapter, pageIndex: i)
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
        case let .chapterPageForCachingFetched(result, chapter, pageIndex):
            switch result {
            case .success(let chapterPage):
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
                
            case .failure(let error):
                logger.error(
                    "Failed to fetch image(\(pageIndex)) for caching in OnlineMangaViewLoaderFeature: \(error)"
                )
                
                var effects: [EffectTask<Action>] = [
                    databaseClient
                        .deleteChapter(chapterID: chapter.id)
                        .fireAndForget(),
                    
                    .cancel(id: CancelChapterCache())
                ]
                
                if let pagesCount = databaseClient.retrieveChapter(chapterID: chapter.id)?.pagesCount {
                    effects.append(
                        mangaClient.removeCachedPagesForChapter(chapter.id, pagesCount, cacheClient).fireAndForget()
                    )
                }
                
                return .merge(effects)
            }
            
        // to be hijacked in OnlineMangaReadingViewFeature
        case .chapterCached:
            return .none
        }
    }
}
