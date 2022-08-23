//
//  OfflineMangaReadingViewStore.swift
//  Smuggler
//
//  Created by mk.pwnz on 23/08/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

struct OfflineMangaReadingViewState: Equatable {
    init(mangaID: UUID, chapter: ChapterDetails, pagesCount: Int, shouldSendUserToTheLastPage: Bool) {
        self.mangaID = mangaID
        self.chapter = chapter
        self.pagesCount = pagesCount
        self.shouldSendUserToTheLastPage = shouldSendUserToTheLastPage
    }
    
    let mangaID: UUID
    let chapter: ChapterDetails
    let shouldSendUserToTheLastPage: Bool
    let pagesCount: Int
    
    var cachedPages: [UIImage?] = []
    var sameScanlationGroupChapters: [ChapterDetails] = []
}

enum OfflineMangaReadingViewAction {
    case userStartedReadingChapter
    case userChangedPage(newPageIndex: Int)
    
    case userHitLastPage
    case userHitTheMostFirstPage
    case userLeftMangaReadingView
    
    case cachedChapterPageRetrieved(result: Result<UIImage, Error>, pageIndex: Int)
    case sameScanlationGroupChaptersFetched(Result<[ChapterDetails], AppError>)
}


    // swiftlint:disable:next line_length
let offlineMangaReadingViewReducer: Reducer<OfflineMangaReadingViewState, OfflineMangaReadingViewAction, MangaReadingViewEnvironment> = .combine(
    Reducer { state, action, env in
        switch action {
            case .userStartedReadingChapter:
                guard state.cachedPages.isEmpty else {
                    return .none
                }
                
                state.cachedPages = Array(repeating: nil, count: state.pagesCount)
                
                var effects: [Effect<OfflineMangaReadingViewAction, Never>] = (0..<state.pagesCount).indices
                    .map { pageIndex in
                        env.mangaClient.retrieveChapterPage(state.chapter.id, pageIndex, env.cacheClient)
                            .map {
                                OfflineMangaReadingViewAction.cachedChapterPageRetrieved(
                                    result: $0,
                                    pageIndex: pageIndex
                                )
                            }
                    }
                
                effects.append(
                    env.databaseClient.fetchChaptersForManga(
                        mangaID: state.mangaID, scanlationGroupID: state.chapter.scanlationGroupID
                    )
                    .catchToEffect(OfflineMangaReadingViewAction.sameScanlationGroupChaptersFetched)
                )
                
                return .merge(effects)
                
            case .sameScanlationGroupChaptersFetched(let result):
                switch result {
                    case .success(let chapters):
                        state.sameScanlationGroupChapters = chapters.sorted {
                            ($0.attributes.chapterIndex ?? -1) < ($1.attributes.chapterIndex ?? -1)
                        }
                        return .none
                        
                    case .failure(let error):
                        print(error)
                        return .none
                }
                
            case .userChangedPage(let newPageIndex):
                if newPageIndex == -1 {
                    return Effect(value: .userHitTheMostFirstPage)
                } else if newPageIndex == state.pagesCount {
                    return Effect(value: .userHitLastPage)
                }
                
                return .none
                
            case .cachedChapterPageRetrieved(let result, let pageIndex):
                switch result {
                    case .success(let image):
                        state.cachedPages[pageIndex] = image
                        return .none
                        
                    case .failure(let error):
                        print(error)
                        return .none
                }
                
            case .userHitLastPage:
                let nextChapterIndex = env.mangaClient.computeNextChapterIndex(
                    state.chapter.attributes.chapterIndex, state.sameScanlationGroupChapters.map(\.asChapter)
                )
                
                guard let nextChapterIndex = nextChapterIndex else {
                    env.hudClient.show(message: "🙁 You've read the last chapter from this scanlation group.")
                    return Effect(value: .userLeftMangaReadingView)
                }
                
                let nextChapter = state.sameScanlationGroupChapters[nextChapterIndex]
                guard let pagesCount = env.databaseClient.fetchChapter(chapterID: nextChapter.id)?.pagesCount else {
                    env.hudClient.show(message: "🙁 Internal error occured.")
                    return .none
                }
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = OfflineMangaReadingViewState(
                    mangaID: state.mangaID,
                    chapter: nextChapter,
                    pagesCount: pagesCount,
                    shouldSendUserToTheLastPage: false
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return Effect(value: .userStartedReadingChapter)
                
            case .userHitTheMostFirstPage:
                let previousChapterIndex = env.mangaClient.computePreviousChapterIndex(
                    state.chapter.attributes.chapterIndex, state.sameScanlationGroupChapters.map(\.asChapter)
                )
                
                guard let previousChapterIndex = previousChapterIndex else {
                    env.hudClient.show(message: "🤔 You've read the first chapter from this scanlation group.")
                    return Effect(value: .userLeftMangaReadingView)
                }
                
                let previousChapter = state.sameScanlationGroupChapters[previousChapterIndex]

                guard let pagesCount = env.databaseClient.fetchChapter(chapterID: previousChapter.id)?.pagesCount else {
                    env.hudClient.show(message: "🙁 Internal error occured.")
                    return .none
                }
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = OfflineMangaReadingViewState(
                    mangaID: state.mangaID,
                    chapter: previousChapter,
                    pagesCount: pagesCount,
                    shouldSendUserToTheLastPage: true
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return Effect(value: .userStartedReadingChapter)
                
            case .userLeftMangaReadingView:
                return .none
        }
    }
)
