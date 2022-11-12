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
        
        // if user reaches this index, means we have to send him to the next chapter
        let afterLastPageIndex = 999
        
        var pagesInfo: ChapterPagesInfo?
        
        var pagesCount: Int? {
            pagesInfo?.pagesURLs.count
        }
        
        var sameScanlationGroupChapters: [Chapter] = []
    }
    
    enum Action {
        case userStartedReadingChapter
        case chapterPagesInfoFetched(Result<ChapterPagesInfo, AppError>)
        case userChangedPage(newPageIndex: Int)
        
        case sameScanlationGroupChaptersFetched(Result<VolumesContainer, AppError>)
        
        case moveToNextChapter
        case moveToPreviousChapter
        case changeChapter(newChapterIndex: Double)
        case userLeftMangaReadingView
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.logger) private var logger
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .userStartedReadingChapter:
            var effects: [Effect<Action, Never>] = []
            
            if state.pagesInfo == nil {
                effects.append(
                    mangaClient.fetchPagesInfo(state.chapterID)
                        .receive(on: DispatchQueue.main)
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
                    .receive(on: DispatchQueue.main)
                    .catchToEffect(Action.sameScanlationGroupChaptersFetched)
                )
            }
            
            return .merge(effects)
            
        case .chapterPagesInfoFetched(let result):
            switch result {
            case .success(let chapterPagesInfo):
                state.pagesInfo = chapterPagesInfo
                
                return imageClient
                    .prefetchImages(chapterPagesInfo.pagesURLs)
                    .fireAndForget()
                
            case .failure(let error):
                logger.error(
                    "Failed to load chapterPagesInfo: \(error)",
                    context: ["chapterID": "\(state.chapterID.uuidString.lowercased())"]
                )
                return .none
            }
            
        case .userChangedPage(let newPageIndex):
            guard state.pagesInfo != nil else { return .none }
            
            if newPageIndex == -1 {
                return .task { .moveToPreviousChapter }
            } else if newPageIndex == state.afterLastPageIndex {
                return .task { .moveToNextChapter }
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
            
        case .changeChapter(let newChapterIndex):
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
            return .none
        }
    }
}
