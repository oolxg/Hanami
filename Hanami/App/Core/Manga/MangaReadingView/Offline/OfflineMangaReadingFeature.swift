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
import SettingsClient
import HUD

@Reducer
struct OfflineMangaReadingFeature {
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
    @Dependency(\.hud) private var hud
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .userStartedReadingChapter:
            DeviceUtil.disableScreenAutoLock()
            guard state.cachedPagesPaths.isEmpty else {
                return .none
            }
            
            imageClient.prefetchImages(with: state.cachedPagesPaths.compactMap { $0 })
            
            return .run { [state = state] send in
                let settingConfigResult = await settingsClient.retireveSettingsConfig()
                await send(.settingsConfigRetrieved(settingConfigResult))
                
                if state.sameScanlationGroupChapters.isEmpty {
                    let chaptersResult = await databaseClient.retrieveChaptersForManga(
                        mangaID: state.mangaID,
                        scanlationGroupID: state.chapter.scanlationGroupID
                    )
                    
                    await send(.sameScanlationGroupChaptersRetrieved(chaptersResult))
                }
            }
            
        case .settingsConfigRetrieved(let result):
            switch result {
            case .success(let config):
                state.readingFormat = config.readingFormat
                
                state.cachedPagesPaths = mangaClient.getPathsForCachedChapterPages(
                    chapterID: state.chapter.id,
                    pagesCount: state.pagesCount
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
            guard !state.cachedPagesPaths.isEmpty else {
                return .none
            }
            
            state.pageIndex = newPageIndex
            
            // we reached most left page of chapter
            if newPageIndex == state.mostLeftPageIndex {
                if state.readingFormat == .rightToLeft {
                    return .run { await $0(.moveToNextChapter) }
                } else {
                    return .run { await $0(.moveToPreviousChapter) }
                }
            // we reached most right page of chapter
            } else if newPageIndex == state.mostRightPageIndex {
                if state.readingFormat == .rightToLeft {
                    return .run { await $0(.moveToPreviousChapter) }
                } else {
                    return .run { await $0(.moveToNextChapter) }
                }
            }
            
            return .none
            
        case .chapterCarouselButtonTapped(let newChapterIndex):
            guard newChapterIndex != state.chapter.attributes.index else {
                return .none
            }
            
            let chapterIndex = mangaClient.getChapterIndex(
                chapterIndexToFind: newChapterIndex,
                scanlationGroupChapters: state.sameScanlationGroupChapters.map(\.asChapter)
            )
            
            guard let chapterIndex else { fatalError("Here must be chapterIndex!") }
            
            let chapter = state.sameScanlationGroupChapters[chapterIndex]
            
            guard let pagesCount = databaseClient.retrieveChapter(byID: chapter.id)?.pagesCount else {
                hud.show(message: "🙁 Internal error occured.")
                return .run { await $0(.userLeftMangaReadingView) }
            }
            
            let sameScanlationGroupChapters = state.sameScanlationGroupChapters
            
            state = State(
                mangaID: state.mangaID,
                chapter: chapter,
                pagesCount: pagesCount,
                startFromLastPage: false
            )
            
            state.sameScanlationGroupChapters = sameScanlationGroupChapters
            
            return .run { await $0(.userStartedReadingChapter) }
            
        case .moveToNextChapter:
            let nextChapterIndex = mangaClient.getNextChapterIndex(
                currentChapterIndex: state.chapter.attributes.index,
                scanlationGroupChapters: state.sameScanlationGroupChapters.map(\.asChapter)
            )
            
            guard let nextChapterIndex else {
                hud.show(message: "🙁 You've read the last chapter from this scanlation group.")
                return .run { await $0(.userLeftMangaReadingView) }
            }
            
            let nextChapter = state.sameScanlationGroupChapters[nextChapterIndex]
            guard let pagesCount = databaseClient.retrieveChapter(byID: nextChapter.id)?.pagesCount else {
                hud.show(message: "🙁 Internal error occured.")
                return .run { await $0(.userLeftMangaReadingView) }
            }
            
            let sameScanlationGroupChapters = state.sameScanlationGroupChapters
            
            state = State(
                mangaID: state.mangaID,
                chapter: nextChapter,
                pagesCount: pagesCount,
                startFromLastPage: false
            )
            
            state.sameScanlationGroupChapters = sameScanlationGroupChapters
            
            return .run { await $0(.userStartedReadingChapter) }
            
        case .moveToPreviousChapter:
            let previousChapterIndex = mangaClient.getPrevChapterIndex(
                currentChapterIndex: state.chapter.attributes.index,
                scanlationGroupChapters: state.sameScanlationGroupChapters.map(\.asChapter)
            )
            
            guard let previousChapterIndex else {
                hud.show(message: "🤔 You've read the first chapter from this scanlation group.")
                return .run { await $0(.userLeftMangaReadingView) }
            }
            
            let previousChapter = state.sameScanlationGroupChapters[previousChapterIndex]
            
            guard let pagesCount = databaseClient.retrieveChapter(byID: previousChapter.id)?.pagesCount else {
                hud.show(message: "🙁 Internal error occured.")
                return .run { await $0(.userLeftMangaReadingView) }
            }
            
            let sameScanlationGroupChapters = state.sameScanlationGroupChapters
            
            state = State(
                mangaID: state.mangaID,
                chapter: previousChapter,
                pagesCount: pagesCount,
                startFromLastPage: true
            )
            
            state.sameScanlationGroupChapters = sameScanlationGroupChapters
            
            return .run { await $0(.userStartedReadingChapter) }
            
        case .userLeftMangaReadingView:
            DeviceUtil.enableScreenAutoLock()
            return .none
        }
    }
}
