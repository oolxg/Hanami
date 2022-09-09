//
//  OfflineMangaReadingViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

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
    
    var cachedPages: [UIImage?] = []
    var sameScanlationGroupChapters: [ChapterDetails] = []
}

enum OfflineMangaReadingViewAction {
    case userStartedReadingChapter
    case userChangedPage(newPageIndex: Int)
    
    case moveToNextChapter
    case moveToPreviousChapter(startFromLastPage: Bool)
    case changeChapter(newChapterIndex: Double)
    case userLeftMangaReadingView
    
    case cachedChapterPageRetrieved(result: Result<UIImage, Error>, pageIndex: Int)
    case sameScanlationGroupChaptersRetrieved(Result<[(chapter: ChapterDetails, pagesCount: Int)], AppError>)
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
                            .map { .cachedChapterPageRetrieved(result: $0, pageIndex: pageIndex) }
                    }
                
                effects.append(
                    env.databaseClient.retrieveChaptersForManga(
                        mangaID: state.mangaID, scanlationGroupID: state.chapter.scanlationGroupID
                    )
                    .catchToEffect(OfflineMangaReadingViewAction.sameScanlationGroupChaptersRetrieved)
                )
                
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
                guard !state.cachedPages.isEmpty else {
                    return .none
                }
                
                if newPageIndex == -1 && state.cachedPages.first! != nil {
                    return Effect(value: .moveToPreviousChapter(startFromLastPage: true))
                } else if newPageIndex == state.pagesCount && state.cachedPages.last! != nil {
                    return Effect(value: .moveToNextChapter)
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
                
            case .changeChapter(let newChapterIndex):
                guard newChapterIndex != state.chapter.attributes.chapterIndex else {
                    return .none
                }
                let chapterIndex = env.mangaClient.computeChapterIndex(
                    newChapterIndex, state.sameScanlationGroupChapters.map(\.asChapter)
                )
                guard let chapterIndex = chapterIndex else { fatalError("Here must be chapterIndex!") }
                
                let chapter = state.sameScanlationGroupChapters[chapterIndex]
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                guard let pagesCount = env.databaseClient.fetchChapter(chapterID: chapter.id)?.pagesCount else {
                    env.hudClient.show(message: "🙁 Internal error occured.")
                    return .none
                }
                
                state = OfflineMangaReadingViewState(
                    mangaID: state.mangaID,
                    chapter: chapter,
                    pagesCount: pagesCount,
                    startFromLastPage: false
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return Effect(value: .userStartedReadingChapter)
                
            case .moveToNextChapter:
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
                    startFromLastPage: false
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return Effect(value: .userStartedReadingChapter)
                
            case .moveToPreviousChapter(let startFromLastPage):
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
                    startFromLastPage: startFromLastPage
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return Effect(value: .userStartedReadingChapter)
                
            case .userLeftMangaReadingView:
                return .none
        }
    }
)
