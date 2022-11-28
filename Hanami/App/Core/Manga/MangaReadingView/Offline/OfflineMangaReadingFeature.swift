//
//  OfflineMangaReadingViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import Foundation
import ComposableArchitecture

struct OfflineMangaReadingFeature: ReducerProtocol {
    struct State: Equatable {
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
    
    enum Action {
        case userStartedReadingChapter
        case currentPageIndexChanged(newPageIndex: Int)
        
        case moveToNextChapter
        case moveToPreviousChapter
        case chapterCarouselButtonTapped(newChapterIndex: Double)
        case userLeftMangaReadingView
        
        case sameScanlationGroupChaptersRetrieved(Result<[CachedChapterEntry], AppError>)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .userStartedReadingChapter:
            guard state.cachedPagesPaths.isEmpty else {
                return .none
            }
            
            state.cachedPagesPaths = mangaClient.getPathsForCachedChapterPages(
                state.chapter.id, state.pagesCount, cacheClient
            )
            
            var effects: [Effect<Action, Never>] = [
                imageClient
                    .prefetchImages(state.cachedPagesPaths.compactMap { $0 })
                    .fireAndForget()
            ]
            
            if state.sameScanlationGroupChapters.isEmpty {
                let mangaID = state.mangaID
                let scanlationGroupID = state.chapter.scanlationGroupID
                effects.append(
                    databaseClient
                        .retrieveAllChaptersForManga(mangaID: mangaID, scanlationGroupID: scanlationGroupID)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(Action.sameScanlationGroupChaptersRetrieved)
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
                logger.error(
                    "Failed to retrieve from disk chapters from current scanlation group: \(error)",
                    context: ["scanlationGroupID": "\(String(describing: state.chapter.scanlationGroupID))"]
                )
                return .none
            }
            
        case .currentPageIndexChanged(let newPageIndex):
            // this checks for some shitty bug(appears rare, but anyway) when user changes chapter(`.userHitLastPage` or `.userHitTheMostFirstPage`)
            // if page is not retrived yet `newPageIndex` is equal to -1 and `.task { .moveToPreviousChapter }` will be returned
            guard !state.cachedPagesPaths.isEmpty else {
                return .none
            }
            
            if newPageIndex == -1 {
                return .task { .moveToPreviousChapter }
            } else if newPageIndex == state.pagesCount {
                return .task { .moveToNextChapter }
            }
            
            return .none
            
        case .chapterCarouselButtonTapped(let newChapterIndex):
            guard newChapterIndex != state.chapter.attributes.chapterIndex else {
                return .none
            }
            
            let chapterIndex = mangaClient.computeChapterIndex(
                newChapterIndex, state.sameScanlationGroupChapters.map(\.asChapter)
            )
            
            guard let chapterIndex else { fatalError("Here must be chapterIndex!") }
            
            let chapter = state.sameScanlationGroupChapters[chapterIndex]
            
            
            guard let pagesCount = databaseClient.retrieveChapter(chapterID: chapter.id)?.pagesCount else {
                hudClient.show(message: "🙁 Internal error occured.")
                return .task { .userLeftMangaReadingView }
            }
            
            let sameScanlationGroupChapters = state.sameScanlationGroupChapters
            
            state = State(
                mangaID: state.mangaID,
                chapter: chapter,
                pagesCount: pagesCount,
                startFromLastPage: false
            )
            
            state.sameScanlationGroupChapters = sameScanlationGroupChapters
            
            return .task { .userStartedReadingChapter }
            
        case .moveToNextChapter:
            let nextChapterIndex = mangaClient.computeNextChapterIndex(
                state.chapter.attributes.chapterIndex, state.sameScanlationGroupChapters.map(\.asChapter)
            )
            
            guard let nextChapterIndex else {
                hudClient.show(message: "🙁 You've read the last chapter from this scanlation group.")
                return .task { .userLeftMangaReadingView }
            }
            
            let nextChapter = state.sameScanlationGroupChapters[nextChapterIndex]
            guard let pagesCount = databaseClient.retrieveChapter(chapterID: nextChapter.id)?.pagesCount else {
                hudClient.show(message: "🙁 Internal error occured.")
                return .task { .userLeftMangaReadingView }
            }
            
            let sameScanlationGroupChapters = state.sameScanlationGroupChapters
            
            state = State(
                mangaID: state.mangaID,
                chapter: nextChapter,
                pagesCount: pagesCount,
                startFromLastPage: false
            )
            
            state.sameScanlationGroupChapters = sameScanlationGroupChapters
            
            return .task { .userStartedReadingChapter }
            
        case .moveToPreviousChapter:
            let previousChapterIndex = mangaClient.computePreviousChapterIndex(
                state.chapter.attributes.chapterIndex, state.sameScanlationGroupChapters.map(\.asChapter)
            )
            
            guard let previousChapterIndex else {
                hudClient.show(message: "🤔 You've read the first chapter from this scanlation group.")
                return .task { .userLeftMangaReadingView }
            }
            
            let previousChapter = state.sameScanlationGroupChapters[previousChapterIndex]
            
            guard let pagesCount = databaseClient.retrieveChapter(chapterID: previousChapter.id)?.pagesCount else {
                hudClient.show(message: "🙁 Internal error occured.")
                return .task { .userLeftMangaReadingView }
            }
            
            let sameScanlationGroupChapters = state.sameScanlationGroupChapters
            
            state = State(
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
}
