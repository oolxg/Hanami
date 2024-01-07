//
//  OnlineMangaReadingViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import Foundation
import ComposableArchitecture
import ModelKit
import Utils
import Logger
import ImageClient
import SettingsClient
import HUD

struct OnlineMangaReadingFeature: Reducer {
    struct State: Equatable {
        init(
            manga: Manga,
            chapterID: UUID,
            chapterIndex: Double?,
            scanlationGroupID: UUID?,
            translatedLanguage: String?,
            startFromLastPage: Bool = false
        ) {
            self.manga = manga
            self.chapterID = chapterID
            self.chapterIndex = chapterIndex
            self.scanlationGroupID = scanlationGroupID
            self.translatedLanguage = translatedLanguage
            self.startFromLastPage = startFromLastPage
        }
        
        let manga: Manga
        let chapterID: UUID
        let translatedLanguage: String?
        let chapterIndex: Double?
        let scanlationGroupID: UUID?
        let startFromLastPage: Bool
        
        // if user reaches one of this indexes, means we have to send him to the next or prev chapter chapter
        let mostRightPageIndex = Int.max
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
        
        var pagesCount: Int? { pagesURLs?.count }
        
        var useHighQualityImages = false
        var readingFormat = SettingsConfig.ReadingFormat.leftToRight
        
        var sameScanlationGroupChapters: [Chapter] = []
        
        var chapterLoader: OnlineMangaViewLoaderFeature.State?
        var isChapterCached = false
    }
    
    enum Action {
        // MARK: - Actions to be called from view
        case userStartedReadingChapter
        case currentPageIndexChanged(newPageIndex: Int)
        case moveToNextChapter
        case moveToPreviousChapter
        case chapterCarouselButtonTapped(newChapterIndex: Double)
        case userLeftMangaReadingView
        case downloadChapterButtonTapped
        case cancelDownloadButtonTapped
        
        // MARK: - Inner actions
        case chapterPagesInfoFetched(Result<ChapterPagesInfo, AppError>)
        case sameScanlationGroupChaptersFetched(Result<VolumesContainer, AppError>)
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        case chapterLoaderFinishedLoadCancellation
        
        case loaderAction(OnlineMangaViewLoaderFeature.Action)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.hud) private var hud
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.logger) private var logger
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .userStartedReadingChapter:
                state.isChapterCached = databaseClient.retrieveChapter(byID: state.chapterID).hasValue
                
                DeviceUtil.disableScreenAutoLock()
                
                return .run { [state = state] send in
                    let result = await settingsClient.retireveSettingsConfig()
                    await send(.settingsConfigRetrieved(result))
                    
                    if state.pagesURLs.isNil {
                        let result = await mangaClient.fetchPagesInfo(for: state.chapterID)
                        await send(.chapterPagesInfoFetched(result))
                    }
                    
                    if state.sameScanlationGroupChapters.isEmpty {
                        let result = await mangaClient.fetchChapters(
                            forMangaWithID: state.manga.id,
                            scanlationGroupID: state.scanlationGroupID,
                            translatedLanguage: state.translatedLanguage
                        )
                        
                        await send(.sameScanlationGroupChaptersFetched(result))
                    }
                }
                
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
                    
                    imageClient.prefetchImages(with: state.pagesURLs!)
                    
                    return .none
                    
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
                        return .run { await $0(.moveToNextChapter) }
                    } else {
                        return .run { await $0(.moveToPreviousChapter) }
                    }
                // we reached most right book of chapter
                } else if newPageIndex == state.mostRightPageIndex {
                    if state.readingFormat == .rightToLeft {
                        return .run { await $0(.moveToPreviousChapter) }
                    } else {
                        return .run { await $0(.moveToNextChapter) }
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
                
            // To be hijacked in parent 'OnlineMangaFeature'
            case .downloadChapterButtonTapped:
                guard !state.isChapterCached, state.chapterLoader.isNil else { return .none }
                
                state.chapterLoader = OnlineMangaViewLoaderFeature.State(
                    parentManga: state.manga,
                    chapterID: state.chapterID,
                    useHighResImagesForCaching: state.useHighQualityImages
                )
                
                return .run { await $0(.loaderAction(.downloadChapterButtonTapped)) }
                
            case .cancelDownloadButtonTapped:
                return .concatenate(
                    .run { await $0(.loaderAction(.cancelDownloadButtonTapped)) },
                    
                    .run { await $0(.chapterLoaderFinishedLoadCancellation) }
                )
                
            case .chapterLoaderFinishedLoadCancellation:
                state.chapterLoader = nil
                return .none
                
            case .chapterCarouselButtonTapped(let newChapterIndex):
                guard newChapterIndex != state.chapterIndex else {
                    return .none
                }
                let chapterIndex = mangaClient.getChapterIndex(
                    chapterIndexToFind: newChapterIndex,
                    scanlationGroupChapters: state.sameScanlationGroupChapters
                )
                
                guard let chapterIndex else { fatalError("Here must be chapterIndex!") }
                
                let chapter = state.sameScanlationGroupChapters[chapterIndex]
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = State(
                    manga: state.manga,
                    chapterID: chapter.id,
                    chapterIndex: chapter.index,
                    scanlationGroupID: state.scanlationGroupID,
                    translatedLanguage: state.translatedLanguage
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return .run { await $0(.userStartedReadingChapter) }
                
            case .moveToNextChapter:
                let nextChapterIndex = mangaClient.getNextChapterIndex(
                    currentChapterIndex: state.chapterIndex,
                    scanlationGroupChapters: state.sameScanlationGroupChapters
                )
                
                guard let nextChapterIndex else {
                    hud.show(message: "🙁 You've read the last chapter from this scanlation group.")
                    return .run { await $0(.userLeftMangaReadingView) }
                }
                
                let nextChapter = state.sameScanlationGroupChapters[nextChapterIndex]
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = State(
                    manga: state.manga,
                    chapterID: nextChapter.id,
                    chapterIndex: nextChapter.index,
                    scanlationGroupID: state.scanlationGroupID,
                    translatedLanguage: state.translatedLanguage
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return .run { await $0(.userStartedReadingChapter) }
                
            case .moveToPreviousChapter:
                let previousChapterIndex = mangaClient.getPrevChapterIndex(
                    currentChapterIndex: state.chapterIndex,
                    scanlationGroupChapters: state.sameScanlationGroupChapters
                )
                
                guard let previousChapterIndex else {
                    hud.show(message: "🤔 You've read the first chapter from this scanlation group.")
                    return .run { await $0(.userLeftMangaReadingView) }
                }
                
                let previousChapter = state.sameScanlationGroupChapters[previousChapterIndex]
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = State(
                    manga: state.manga,
                    chapterID: previousChapter.id,
                    chapterIndex: previousChapter.index,
                    scanlationGroupID: state.scanlationGroupID,
                    translatedLanguage: state.translatedLanguage,
                    startFromLastPage: true
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return .run { await $0(.userStartedReadingChapter) }
                
            case .userLeftMangaReadingView:
                DeviceUtil.enableScreenAutoLock()
                return .none
                
            case .loaderAction(.chapterCached):
                state.isChapterCached = true
                return .none
                
            case .loaderAction:
                return .none
            }
        }
        .ifLet(\.chapterLoader, action: /Action.loaderAction) {
            OnlineMangaViewLoaderFeature()
        }
    }
}
