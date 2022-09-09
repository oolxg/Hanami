//
//  OnlineMangaReadingViewStore.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import Foundation
import ComposableArchitecture


struct OnlineMangaReadingViewState: Equatable {
    init(
        mangaID: UUID,
        chapterID: UUID,
        chapterIndex: Double?,
        scanlationGroupID: UUID?,
        translatedLanguage: String,
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
    let translatedLanguage: String
    let chapterIndex: Double?
    let scanlationGroupID: UUID?
    let startFromLastPage: Bool
    
    var pagesInfo: ChapterPagesInfo?
    
    var pagesCount: Int? {
        pagesInfo?.dataSaverURLs.count
    }
    
    var sameScanlationGroupChapters: [Chapter] = []
}

enum OnlineMangaReadingViewAction {
    case userStartedReadingChapter
    case chapterPagesInfoFetched(Result<ChapterPagesInfo, AppError>)
    case userChangedPage(newPageIndex: Int)
    
    case sameScanlationGroupChaptersFetched(Result<VolumesContainer, AppError>)
    
    case moveToNextChapter
    case moveToPreviousChapters(startFromLastPage: Bool)
    case changeChapter(newChapterIndex: Double)
    case userLeftMangaReadingView
}

// swiftlint:disable:next line_length
let mangaReadingViewReducer: Reducer<MangaReadingViewState, MangaReadingViewAction, MangaReadingViewEnvironment> = .combine(
    onlineMangaReadingViewReducer.pullback(
        state: /MangaReadingViewState.online,
        action: /MangaReadingViewAction.online,
        environment: { .init(
            databaseClient: $0.databaseClient,
            cacheClient: $0.cacheClient,
            imageClient: $0.imageClient,
            mangaClient: $0.mangaClient,
            hudClient: $0.hudClient
        ) }
    ),
    offlineMangaReadingViewReducer.pullback(
        state: /MangaReadingViewState.offline,
        action: /MangaReadingViewAction.offline,
        environment: { .init(
            databaseClient: $0.databaseClient,
            cacheClient: $0.cacheClient,
            imageClient: $0.imageClient,
            mangaClient: $0.mangaClient,
            hudClient: $0.hudClient
        ) }
    )
)

    // swiftlint:disable:next line_length
let onlineMangaReadingViewReducer: Reducer<OnlineMangaReadingViewState, OnlineMangaReadingViewAction, MangaReadingViewEnvironment> = .combine(
    Reducer { state, action, env in
        switch action {
            case .userStartedReadingChapter:
                var effects: [Effect<OnlineMangaReadingViewAction, Never>] = []
                
                if state.pagesInfo == nil {
                    effects.append(
                        env.mangaClient.fetchPagesInfo(state.chapterID)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(OnlineMangaReadingViewAction.chapterPagesInfoFetched)
                    )
                }
                
                if state.sameScanlationGroupChapters.isEmpty {
                    effects.append(
                        env.mangaClient.fetchMangaChapters(
                            state.mangaID,
                            state.scanlationGroupID,
                            state.translatedLanguage
                        )
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(OnlineMangaReadingViewAction.sameScanlationGroupChaptersFetched)
                    )
                }
                
                return .merge(effects)
                
            case .chapterPagesInfoFetched(let result):
                switch result {
                    case .success(let chapterPagesInfo):
                        state.pagesInfo = chapterPagesInfo
                        
                        return env.imageClient
                            .prefetchImages(chapterPagesInfo.dataSaverURLs, nil)
                            .fireAndForget()
                        
                    case .failure(let error):
                        print("error on fetching chapterPagesInfo: \(error)")
                        return .none
                }
                
            case .userChangedPage(let newPageIndex):
                if newPageIndex == -1 {
                    return Effect(value: .moveToPreviousChapters(startFromLastPage: true))
                } else if newPageIndex == state.pagesInfo?.dataSaverURLs.count {
                    return Effect(value: .moveToNextChapter)
                }
                
                return .none
                
            case .sameScanlationGroupChaptersFetched(let result):
                switch result {
                    case .success(let response):
                        state.sameScanlationGroupChapters = response.volumes.flatMap(\.chapters).reversed()
                        return .none
                        
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error)")
                        return .none
                }
                
            case .changeChapter(let newChapterIndex):
                guard newChapterIndex != state.chapterIndex else {
                    return .none
                }
                let chapterIndex = env.mangaClient.computeChapterIndex(
                    newChapterIndex, state.sameScanlationGroupChapters
                )
                
                guard let chapterIndex = chapterIndex else { fatalError("Here must be chapterIndex!") }
                
                let chapter = state.sameScanlationGroupChapters[chapterIndex]
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = OnlineMangaReadingViewState(
                    mangaID: state.mangaID,
                    chapterID: chapter.id,
                    chapterIndex: chapter.chapterIndex,
                    scanlationGroupID: state.scanlationGroupID,
                    translatedLanguage: state.translatedLanguage
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return Effect(value: .userStartedReadingChapter)
                
            case .moveToNextChapter:
                let nextChapterIndex = env.mangaClient.computeNextChapterIndex(
                    state.chapterIndex, state.sameScanlationGroupChapters
                )
                
                guard let nextChapterIndex = nextChapterIndex else {
                    env.hudClient.show(message: "🙁 You've read the last chapter from this scanlation group.")
                    return Effect(value: .userLeftMangaReadingView)
                }
                
                let nextChapter = state.sameScanlationGroupChapters[nextChapterIndex]
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = OnlineMangaReadingViewState(
                    mangaID: state.mangaID,
                    chapterID: nextChapter.id,
                    chapterIndex: nextChapter.chapterIndex,
                    scanlationGroupID: state.scanlationGroupID,
                    translatedLanguage: state.translatedLanguage
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return Effect(value: .userStartedReadingChapter)
                
            case .moveToPreviousChapters(let startFromLastPage):
                let previousChapterIndex = env.mangaClient.computePreviousChapterIndex(
                    state.chapterIndex, state.sameScanlationGroupChapters
                )
                
                guard let previousChapterIndex = previousChapterIndex else {
                    env.hudClient.show(message: "🤔 You've read the first chapter from this scanlation group.")
                    return Effect(value: .userLeftMangaReadingView)
                }
                
                let previousChapter = state.sameScanlationGroupChapters[previousChapterIndex]
                
                let sameScanlationGroupChapters = state.sameScanlationGroupChapters
                
                state = OnlineMangaReadingViewState(
                    mangaID: state.mangaID,
                    chapterID: previousChapter.id,
                    chapterIndex: previousChapter.chapterIndex,
                    scanlationGroupID: state.scanlationGroupID,
                    translatedLanguage: state.translatedLanguage,
                    startFromLastPage: startFromLastPage
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return Effect(value: .userStartedReadingChapter)
                
            case .userLeftMangaReadingView:
                return .none
        }
    }
)
