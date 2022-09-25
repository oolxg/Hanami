//
//  OfflineMangaReadingViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import Foundation
import ComposableArchitecture

struct OfflineMangaReadingViewState: Equatable {
    init(mangaID: UUID, chapter: ChapterDetails, pagesCount: Int, startFromLastPage: Bool) {
        self.mangaID = mangaID
        self.chapter = chapter
        self.pagesCount = pagesCount
        self.startFromLastPage = startFromLastPage
    }
    
    let mangaID: UUID
    let chapter: ChapterDetails
    let startFromLastPage: Bool
    let pagesCount: Int
    
    var cachedPagesPaths: [URL?] = []
    var sameScanlationGroupChapters: [ChapterDetails] = []
}

enum OfflineMangaReadingViewAction {
    case userStartedReadingChapter
    case userChangedPage(newPageIndex: Int)
    
    case moveToNextChapter
    case moveToPreviousChapter
    case changeChapter(newChapterIndex: Double)
    case userLeftMangaReadingView
    
    case sameScanlationGroupChaptersRetrieved(Result<[CachedChapterEntry], AppError>)
}


// swiftlint:disable:next line_length
let offlineMangaReadingViewReducer: Reducer<OfflineMangaReadingViewState, OfflineMangaReadingViewAction, MangaReadingViewEnvironment> = .combine(
    Reducer { state, action, env in
        switch action {
            case .userStartedReadingChapter:
                guard state.cachedPagesPaths.isEmpty else {
                    return .none
                }
                
                state.cachedPagesPaths = env.mangaClient.getPathsForCachedChapterPages(
                    state.chapter.id, state.pagesCount, env.cacheClient
                )
                
                var effects: [Effect<OfflineMangaReadingViewAction, Never>] = [
                    env.imageClient
                        .prefetchImages(state.cachedPagesPaths.compactMap { $0 })
                        .fireAndForget()
                ]
                
                if state.sameScanlationGroupChapters.isEmpty {
                    let mangaID = state.mangaID
                    let scanlationGroupID = state.chapter.scanlationGroupID
                    effects.append(
                        env.databaseClient
                            .retrieveChaptersForManga(mangaID: mangaID, scanlationGroupID: scanlationGroupID)
                            .catchToEffect(OfflineMangaReadingViewAction.sameScanlationGroupChaptersRetrieved)
                    )
                }
                
                return .merge(effects)
                
            case .sameScanlationGroupChaptersRetrieved(let result):
                switch result {
                    case .success(let chapters):
                        state.sameScanlationGroupChapters = chapters.map(\.chapter).sorted {
                            ($0.attributes.chapterIndex ?? -1) < ($1.attributes.chapterIndex ?? -1)
                        }
                        return .none
                        
                    case .failure(let error):
                        print(error)
                        return .none
                }
                
            case .userChangedPage(let newPageIndex):
                // this checks for some shitty bug(appears rare, but anyway) when user changes chapter(`.userHitLastPage` or `.userHitTheMostFirstPage`)
                // if page is not retrived yet `newPageIndex` is equal to -1 and Effect(value:) will be returned
                guard !state.cachedPagesPaths.isEmpty else {
                    return .none
                }
                
                if newPageIndex == -1 {
                    return .task { .moveToPreviousChapter }
                } else if newPageIndex == state.pagesCount {
                    return .task { .moveToNextChapter }
                }
                
                return .none
                
            case .changeChapter(let newChapterIndex):
                guard newChapterIndex != state.chapter.attributes.chapterIndex else {
                    return .none
                }
                
                let chapterIndex = env.mangaClient.computeChapterIndex(
                    newChapterIndex, state.sameScanlationGroupChapters.map(\.asChapter)
                )
                
                guard let chapterIndex = chapterIndex else { fatalError("Here must be chapterIndex!") }
                
                let chapter = state.sameScanlationGroupChapters[chapterIndex]
                
                
                guard let pagesCount = env.databaseClient.fetchChapter(chapterID: chapter.id)?.pagesCount else {
                    env.hudClient.show(message: "🙁 Internal error occured.")
                    return .task { .userLeftMangaReadingView }
                }
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = OfflineMangaReadingViewState(
                    mangaID: state.mangaID,
                    chapter: chapter,
                    pagesCount: pagesCount,
                    startFromLastPage: false
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return .task { .userStartedReadingChapter }
                
            case .moveToNextChapter:
                let nextChapterIndex = env.mangaClient.computeNextChapterIndex(
                    state.chapter.attributes.chapterIndex, state.sameScanlationGroupChapters.map(\.asChapter)
                )
                
                guard let nextChapterIndex = nextChapterIndex else {
                    env.hudClient.show(message: "🙁 You've read the last chapter from this scanlation group.")
                    return .task { .userLeftMangaReadingView }
                }
                
                let nextChapter = state.sameScanlationGroupChapters[nextChapterIndex]
                guard let pagesCount = env.databaseClient.fetchChapter(chapterID: nextChapter.id)?.pagesCount else {
                    env.hudClient.show(message: "🙁 Internal error occured.")
                    return .task { .userLeftMangaReadingView }
                }
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = OfflineMangaReadingViewState(
                    mangaID: state.mangaID,
                    chapter: nextChapter,
                    pagesCount: pagesCount,
                    startFromLastPage: false
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return .task { .userStartedReadingChapter }
                
            case .moveToPreviousChapter:
                let previousChapterIndex = env.mangaClient.computePreviousChapterIndex(
                    state.chapter.attributes.chapterIndex, state.sameScanlationGroupChapters.map(\.asChapter)
                )
                
                guard let previousChapterIndex = previousChapterIndex else {
                    env.hudClient.show(message: "🤔 You've read the first chapter from this scanlation group.")
                    return .task { .userLeftMangaReadingView }
                }
                
                let previousChapter = state.sameScanlationGroupChapters[previousChapterIndex]

                guard let pagesCount = env.databaseClient.fetchChapter(chapterID: previousChapter.id)?.pagesCount else {
                    env.hudClient.show(message: "🙁 Internal error occured.")
                    return .task { .userLeftMangaReadingView }
                }
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = OfflineMangaReadingViewState(
                    mangaID: state.mangaID,
                    chapter: previousChapter,
                    pagesCount: pagesCount,
                    startFromLastPage: true
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return .task { .userStartedReadingChapter }
                
            case .userLeftMangaReadingView:
                return .none
        }
    }
)
