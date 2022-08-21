//
//  MangaReadingViewFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import Foundation
import ComposableArchitecture
import Kingfisher
import class SwiftUI.UIImage

struct MangaReadingViewState: Equatable {
    init(chapterID: UUID, chapterIndex: Double?, shouldSendUserToTheLastPage: Bool = false, pagesCount: Int? = nil, isOnline: Bool) {
        self.chapterID = chapterID
        self.chapterIndex = chapterIndex
        self.shouldSendUserToTheLastPage = shouldSendUserToTheLastPage
        self.pagesCount = pagesCount
        self.isOnline = isOnline
    }
    
    let chapterID: UUID
    let chapterIndex: Double?
    // this will be used, when user get to this chapter from the next following one
    let shouldSendUserToTheLastPage: Bool
    let isOnline: Bool
    
    var pagesInfo: ChapterPagesInfo?
    var pagesCount: Int?
    
    var cachedPages: [UIImage] = []
}

enum MangaReadingViewAction {
    case userStartedReadingChapter
    case chapterPagesInfoFetched(Result<ChapterPagesInfo, AppError>)
    case userChangedPage(newPageIndex: Int)
    
    case cachedChapterPageRetrieved(result: Result<UIImage, Error>)

    // MARK: - Actions to be hijacked in MangaFeature
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
    Reducer { state, action, env in
        guard state.isOnline else { return .none }
        
        switch action {
            case .userStartedReadingChapter:
                guard state.pagesInfo == nil else {
                    return .none
                }
                
                return env.mangaClient.fetchPagesInfo(state.chapterID)
                    .receive(on: DispatchQueue.main)
                    .catchToEffect(MangaReadingViewAction.chapterPagesInfoFetched)
                
            case .chapterPagesInfoFetched(let result):
                switch result {
                    case .success(let chapterPagesInfo):
                        state.pagesInfo = chapterPagesInfo
                        state.pagesCount = chapterPagesInfo.dataSaverURLs.count
                        
                        return env.imageClient
                            .prefetchImages(chapterPagesInfo.dataSaverURLs)
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
                
            // MARK: - Actions to be hijacked in MangaFeature
            case .userHitLastPage:
                return .none
                
            case .userHitTheMostFirstPage:
                return .none
                
            case .userLeftMangaReadingView:
                return .none
                
            case .cachedChapterPageRetrieved:
                return .none
        }
    },
    
    Reducer { state, action, env in
        guard !state.isOnline else { return .none }
        
        switch action {
            case .userStartedReadingChapter:
                guard let pagesCount = env.databaseClient.fetchChapter(chapterID: state.chapterID)?.pagesCount else {
                    env.hudClient.show(message: "😢 Error on retrieving saved chapter")
                    return .none
                }
                
                guard state.cachedPages.isEmpty else {
                    return .none
                }
                
                return .concatenate(
                    (0..<pagesCount).indices.map { pageIndex in
                        env.mangaClient.retrieveChapterPage(state.chapterID, pageIndex, env.cacheClient)
                            .map(MangaReadingViewAction.cachedChapterPageRetrieved)
                    }
                )
                
            case .cachedChapterPageRetrieved(let result):
                switch result {
                    case .success(let image):
                        state.cachedPages.append(image)
                        return .none
                        
                    case .failure(let error):
                        print(error)
                        return .none
                }
                
            // MARK: - Actions to be hijacked in MangaFeature
            case .userChangedPage(let newPageIndex):
                if newPageIndex == -1 {
                    return Effect(value: .userHitTheMostFirstPage)
                } else if newPageIndex == state.pagesInfo?.dataSaverURLs.count {
                    return Effect(value: .userHitLastPage)
                }
                
                return .none
                
            case .userHitLastPage:
                return .none
                
            case .userHitTheMostFirstPage:
                return .none
                
            case .userLeftMangaReadingView:
                return .none
                
            case .chapterPagesInfoFetched:
                return .none
        }
    }
)
