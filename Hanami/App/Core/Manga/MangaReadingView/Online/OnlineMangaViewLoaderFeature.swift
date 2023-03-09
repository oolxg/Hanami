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
        let useHighResImagesForCaching: Bool
        // swiftlint:disable:next implicitly_unwrapped_optional
        var chapter: ChapterDetails!
        var pagesFetched = 0
        var pagesCount: Int?
    }
    
    enum Action {
        case downloadChapterButtonTapped(UUID)
        case cancelDownloadButtonTapped(UUID)
        case chapterDetailsFetched(Result<Response<ChapterDetails>, AppError>)
        case pagesInfoForChapterCachingFetched(Result<ChapterPagesInfo, AppError>)
        case chapterPageForCachingFetched(Result<UIImage, AppError>, pageIndex: Int)
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
        struct CancelChapterCache: Hashable { let id: UUID }

        switch action {
        case let .downloadChapterButtonTapped(chapterID):
            if databaseClient.retrieveChapter(chapterID: chapterID).isNil {
                return mangaClient.fetchChapterDetails(chapterID)
                    .receive(on: mainQueue)
                    .catchToEffect(Action.chapterDetailsFetched)
            }
            
            return .none
            
        case let .cancelDownloadButtonTapped(chapterID):
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
                
        case let .chapterDetailsFetched(result):
            switch result {
            case .success(let response):
                state.chapter = response.data
                
                return mangaClient.fetchPagesInfo(state.chapter.id)
                    .receive(on: mainQueue)
                    .catchToEffect(Action.pagesInfoForChapterCachingFetched)
                
            case .failure(let error):
                logger.error("Can't fetch chapterDetails for caching in OnlineMangaViewLoaderFeature: \(error)")
                return .none
            }
            
        case let .pagesInfoForChapterCachingFetched(result):
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
                                Action.chapterPageForCachingFetched($0, pageIndex: i)
                            }
                    }
                
                effects.append(
                    databaseClient.saveChapterDetails(
                        state.chapter,
                        pagesCount: pagesURLs.count,
                        parentManga: state.parentManga
                    )
                    .fireAndForget()
                )
                
                return .merge(effects)
                    .cancellable(id: CancelChapterCache(id: state.chapter.id))
                
            case .failure(let error):
                logger.error(
                    "Failed to fetch pagesInfo for caching: \(error)",
                    context: [
                        "mangaID": "\(state.parentManga.id.uuidString.lowercased())",
                        "chapterID": "\(state.chapter.id.uuidString.lowercased())"
                    ]
                )
                
                hudClient.show(message: "Failed to cache chapter \(state.chapter.chapterName)")
                
                return .merge(
                    .cancel(id: CancelChapterCache(id: state.chapter.id)),
                    
                    databaseClient
                        .deleteChapter(chapterID: state.chapter.id)
                        .fireAndForget()
                )
            }
        case let .chapterPageForCachingFetched(result, pageIndex):
            switch result {
            case .success(let chapterPage):
                state.pagesFetched += 1
                
                return .merge(
                    mangaClient
                        .saveChapterPage(chapterPage, pageIndex, state.chapter.id, cacheClient)
                        .cancellable(id: CancelChapterCache(id: state.chapter.id))
                        .fireAndForget(),
                    
                    cacheClient
                        .saveCachedChapterInMemory(state.parentManga.id, state.chapter.id)
                        .fireAndForget(),
                    
                    state.pagesFetched == state.pagesCount ? .task { .chapterCached } : .none
                )
                
            case .failure(let error):
                logger.error(
                    "Failed to fetch image(\(pageIndex)) for caching in OnlineMangaViewLoaderFeature: \(error)"
                )
                
                var effects: [EffectTask<Action>] = [
                    databaseClient
                        .deleteChapter(chapterID: state.chapter.id)
                        .fireAndForget(),
                    
                    .cancel(id: CancelChapterCache(id: state.chapter.id))
                ]
                
                if let pagesCount = databaseClient.retrieveChapter(chapterID: state.chapter.id)?.pagesCount {
                    effects.append(
                        mangaClient.removeCachedPagesForChapter(state.chapter.id, pagesCount, cacheClient).fireAndForget()
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
