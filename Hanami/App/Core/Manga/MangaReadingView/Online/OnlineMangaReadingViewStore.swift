//
//  OnlineMangaReadingViewStore.swift
//  Smuggler
//
//  Created by mk.pwnz on 23/08/2022.
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
        shouldSendUserToTheLastPage: Bool = false
    ) {
        self.mangaID = mangaID
        self.chapterID = chapterID
        self.chapterIndex = chapterIndex
        self.scanlationGroupID = scanlationGroupID
        self.translatedLanguage = translatedLanguage
        self.shouldSendUserToTheLastPage = shouldSendUserToTheLastPage
    }
    
    let mangaID: UUID
    let chapterID: UUID
    let translatedLanguage: String
    let chapterIndex: Double?
    let scanlationGroupID: UUID?
    let shouldSendUserToTheLastPage: Bool
    
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
    
    case userHitLastPage
    case userHitTheMostFirstPage
    case userLeftMangaReadingView
}

struct MangaReadingViewEnvironment {
    let mangaClient: MangaClient
    let imageClient: ImageClient
    let hudClient: HUDClient
    let databaseClient: DatabaseClient
    let cacheClient: CacheClient
}

    // swiftlint:disable:next line_length
let mangaReadingViewReducer: Reducer<MangaReadingViewState, MangaReadingViewAction, MangaReadingViewEnvironment> = .combine(
    onlineMangaReadingViewReducer.pullback(
        state: /MangaReadingViewState.online,
        action: /MangaReadingViewAction.online,
        environment: { .init(
            mangaClient: $0.mangaClient,
            imageClient: $0.imageClient,
            hudClient: $0.hudClient,
            databaseClient: $0.databaseClient,
            cacheClient: $0.cacheClient
        ) }
    ),
    offlineMangaReadingViewReducer.pullback(
        state: /MangaReadingViewState.offline,
        action: /MangaReadingViewAction.offline,
        environment: { .init(
            mangaClient: $0.mangaClient,
            imageClient: $0.imageClient,
            hudClient: $0.hudClient,
            databaseClient: $0.databaseClient,
            cacheClient: $0.cacheClient
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
                    return Effect(value: .userHitTheMostFirstPage)
                } else if newPageIndex == state.pagesInfo?.dataSaverURLs.count {
                    return Effect(value: .userHitLastPage)
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
                
            case .userHitLastPage:
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
                
            case .userHitTheMostFirstPage:
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
                    shouldSendUserToTheLastPage: true
                )
                
                state.sameScanlationGroupChapters = sameScanlationGroupChapters
                
                return Effect(value: .userStartedReadingChapter)
                
            case .userLeftMangaReadingView:
                return .none
        }
    }
)
