//
//  OfflineMangaReadingViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import Foundation
import ComposableArchitecture
import Utils
import ModelKit
import Logger
import ImageClient

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
        var pageIndex = 0
        var pageIndexToDisplay: Int? {
            if pageIndex > mostLeftPageIndex && pageIndex < mostRightPageIndex, readingFormat != .vertical {
                return readingFormat == .rightToLeft ? pagesCount - pageIndex : pageIndex + 1
            }
            return nil
        }
        var readingFormat = SettingsConfig.ReadingFormat.leftToRight
        
        let mostLeftPageIndex = -1
        var mostRightPageIndex: Int { pagesCount }
        
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
        
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        case sameScanlationGroupChaptersRetrieved(Result<[CoreDataChapterDetailsEntry], AppError>)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .userStartedReadingChapter:
            DeviceUtil.disableScreenAutoLock()
            guard state.cachedPagesPaths.isEmpty else {
                return .none
            }
            
            imageClient.prefetchImages(with: state.cachedPagesPaths.compactMap { $0 })
            
            return .concatenate(
                settingsClient.retireveSettingsConfig()
                    .receive(on: mainQueue)
                    .catchToEffect(Action.settingsConfigRetrieved),
                
                state.sameScanlationGroupChapters.isEmpty == false ? .none :
                    databaseClient
                        .retrieveAllChaptersForManga(mangaID: state.mangaID, scanlationGroupID: state.chapter.scanlationGroupID)
                        .receive(on: mainQueue)
                        .catchToEffect(Action.sameScanlationGroupChaptersRetrieved)
            )
            
        case .settingsConfigRetrieved(let result):
            switch result {
            case .success(let config):
                state.readingFormat = config.readingFormat
                
                state.cachedPagesPaths = mangaClient.getPathsForCachedChapterPages(
                    state.chapter.id, state.pagesCount, cacheClient
                )
                
                if state.readingFormat == .rightToLeft {
                    state.cachedPagesPaths.reverse()
                    state.pageIndex = state.startFromLastPage ? 0 : state.pagesCount - 1
                } else {
                    state.pageIndex = state.startFromLastPage ? state.pagesCount - 1 : 0
                }
                
                return .none
                
            case .failure(let error):
                logger.error("Failed to retrieve settingsConfig: \(error)")
                return .none
            }
            
        case .sameScanlationGroupChaptersRetrieved(let result):
            switch result {
            case .success(let chapters):
                state.sameScanlationGroupChapters = chapters.map(\.chapter).sorted {
                    ($0.attributes.index ?? -1) < ($1.attributes.index ?? -1)
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
            
            state.pageIndex = newPageIndex
            
            // we reached most left page of chapter
            if newPageIndex == state.mostLeftPageIndex {
                if state.readingFormat == .rightToLeft {
                    return .task { .moveToNextChapter }
                } else {
                    return .task { .moveToPreviousChapter }
                }
            // we reached most right book of chapter
            } else if newPageIndex == state.mostRightPageIndex {
                if state.readingFormat == .rightToLeft {
                    return .task { .moveToPreviousChapter }
                } else {
                    return .task { .moveToNextChapter }
                }
            }
            
            return .none
            
        case .chapterCarouselButtonTapped(let newChapterIndex):
            guard newChapterIndex != state.chapter.attributes.index else {
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
                state.chapter.attributes.index, state.sameScanlationGroupChapters.map(\.asChapter)
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
                state.chapter.attributes.index, state.sameScanlationGroupChapters.map(\.asChapter)
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
            DeviceUtil.enableScreenAutoLock()
            return .none
        }
    }
}
