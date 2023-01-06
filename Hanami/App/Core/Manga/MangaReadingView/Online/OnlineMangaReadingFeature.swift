//
//  OnlineMangaReadingViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import Foundation
import ComposableArchitecture

struct OnlineMangaReadingFeature: ReducerProtocol {
    struct State: Equatable {
        init(
            mangaID: UUID,
            chapterID: UUID,
            chapterIndex: Double?,
            scanlationGroupID: UUID?,
            translatedLanguage: String?,
            startFromLastPage: Bool = false
        ) {
            self.mangaID = mangaID
            self.chapterID = chapterID
            self.chapterIndex = chapterIndex
            self.scanlationGroupID = scanlationGroupID
            self.translatedLanguage = translatedLanguage
            self.startFromLastPage = startFromLastPage
        }
        
        let mangaID: UUID
        let chapterID: UUID
        let translatedLanguage: String?
        let chapterIndex: Double?
        let scanlationGroupID: UUID?
        let startFromLastPage: Bool
        
        // if user reaches one of this indexes, means we have to send him to the next or prev chapter chapter
        let mostRightPageIndex = 9999
        let mostLeftPageIndex = -1
        
        var pagesURLs: [URL]?
        
        var pageIndex = 0
        var pageIndexToDisplay: Int? {
            if let pagesCount, pageIndex > mostLeftPageIndex
                && pageIndex < mostRightPageIndex, readingFormat != .vertical {
                return readingFormat == .rightToLeft ? pagesCount - pageIndex : pageIndex + 1
            }
            return nil
        }
        
        var pagesCount: Int? {
            pagesURLs?.count
        }
        
        var useHighQualityImages = false
        var readingFormat = SettingsConfig.ReadingFormat.leftToRight
        
        var sameScanlationGroupChapters: [Chapter] = []
    }
    
    enum Action {
        case userStartedReadingChapter
        case chapterPagesInfoFetched(Result<ChapterPagesInfo, AppError>)
        case currentPageIndexChanged(newPageIndex: Int)
        
        case sameScanlationGroupChaptersFetched(Result<VolumesContainer, AppError>)

        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)

        case moveToNextChapter
        case moveToPreviousChapter
        case chapterCarouselButtonTapped(newChapterIndex: Double)
        case userLeftMangaReadingView
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .userStartedReadingChapter:
            DeviceUtil.disableScreenAutoLock()
            
            var effects = [
                settingsClient.getSettingsConfig()
                    .receive(on: mainQueue)
                    .catchToEffect(Action.settingsConfigRetrieved)
            ]
            
            if state.pagesURLs.isNil {
                effects.append(
                    mangaClient.fetchPagesInfo(state.chapterID)
                        .receive(on: mainQueue)
                        .catchToEffect(Action.chapterPagesInfoFetched)
                )
            }
            
            if state.sameScanlationGroupChapters.isEmpty {
                effects.append(
                    mangaClient.fetchMangaChapters(
                        state.mangaID,
                        state.scanlationGroupID,
                        state.translatedLanguage
                    )
                    .receive(on: mainQueue)
                    .catchToEffect(Action.sameScanlationGroupChaptersFetched)
                )
            }
            
            return .concatenate(effects)
            
        case .settingsConfigRetrieved(let result):
            switch result {
            case .success(let config):
                state.useHighQualityImages = config.useHigherQualityImagesForOnlineReading
                state.readingFormat = config.readingFormat
                return .none
                
            case .failure(let error):
                logger.error("Failed to retrieve settingsConfig: \(error)")
                return .none
            }
            
            
        case .chapterPagesInfoFetched(let result):
            switch result {
            case .success(let chapterPagesInfo):
                state.pagesURLs = chapterPagesInfo.getPagesURLs(highQuality: state.useHighQualityImages)
                
                if state.readingFormat == .rightToLeft {
                    state.pagesURLs!.reverse()
                }
                
                if state.readingFormat == .rightToLeft {
                    state.pageIndex = state.startFromLastPage ? 0 : state.pagesCount! - 1
                } else if state.readingFormat == .leftToRight {
                    state.pageIndex = state.startFromLastPage ? state.pagesCount! - 1 : 0
                }
                
                return imageClient
                    .prefetchImages(state.pagesURLs!)
                    .fireAndForget()
                
            case .failure(let error):
                logger.error(
                    "Failed to load chapterPagesInfo: \(error)",
                    context: ["chapterID": "\(state.chapterID.uuidString.lowercased())"]
                )
                return .none
            }
            
        case .currentPageIndexChanged(let newPageIndex):
            guard state.pagesURLs.hasValue else { return .none }
            
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
            
        case .sameScanlationGroupChaptersFetched(let result):
            switch result {
            case .success(let response):
                state.sameScanlationGroupChapters = response.volumes.flatMap(\.chapters).reversed()
                return .none
                
            case .failure(let error):
                logger.error(
                    "Failed to load chapters from current scanlation group: \(error)",
                    context: ["scanlationGroupID": "\(String(describing: state.scanlationGroupID))"]
                )
                return .none
            }
            
        case .chapterCarouselButtonTapped(let newChapterIndex):
            guard newChapterIndex != state.chapterIndex else {
                return .none
            }
            let chapterIndex = mangaClient.computeChapterIndex(
                newChapterIndex, state.sameScanlationGroupChapters
            )
            
            guard let chapterIndex else { fatalError("Here must be chapterIndex!") }
            
            let chapter = state.sameScanlationGroupChapters[chapterIndex]
            
            let sameScanlationGroupChapters = state.sameScanlationGroupChapters
            
            state = State(
                mangaID: state.mangaID,
                chapterID: chapter.id,
                chapterIndex: chapter.chapterIndex,
                scanlationGroupID: state.scanlationGroupID,
                translatedLanguage: state.translatedLanguage
            )
            
            state.sameScanlationGroupChapters = sameScanlationGroupChapters
            
            return .task { .userStartedReadingChapter }
            
        case .moveToNextChapter:
            let nextChapterIndex = mangaClient.computeNextChapterIndex(
                state.chapterIndex, state.sameScanlationGroupChapters
            )
            
            guard let nextChapterIndex else {
                hudClient.show(message: "🙁 You've read the last chapter from this scanlation group.")
                return .task { .userLeftMangaReadingView }
            }
            
            let nextChapter = state.sameScanlationGroupChapters[nextChapterIndex]
            
            let sameScanlationGroupChapters = state.sameScanlationGroupChapters
            
            state = State(
                mangaID: state.mangaID,
                chapterID: nextChapter.id,
                chapterIndex: nextChapter.chapterIndex,
                scanlationGroupID: state.scanlationGroupID,
                translatedLanguage: state.translatedLanguage
            )
            
            state.sameScanlationGroupChapters = sameScanlationGroupChapters
            
            return .task { .userStartedReadingChapter }
            
        case .moveToPreviousChapter:
            let previousChapterIndex = mangaClient.computePreviousChapterIndex(
                state.chapterIndex, state.sameScanlationGroupChapters
            )
            
            guard let previousChapterIndex else {
                hudClient.show(message: "🤔 You've read the first chapter from this scanlation group.")
                return .task { .userLeftMangaReadingView }
            }
            
            let previousChapter = state.sameScanlationGroupChapters[previousChapterIndex]
            
            let sameScanlationGroupChapters = state.sameScanlationGroupChapters
            
            state = State(
                mangaID: state.mangaID,
                chapterID: previousChapter.id,
                chapterIndex: previousChapter.chapterIndex,
                scanlationGroupID: state.scanlationGroupID,
                translatedLanguage: state.translatedLanguage,
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
