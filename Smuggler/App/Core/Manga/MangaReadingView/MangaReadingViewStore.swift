//
//  MangaReadingViewFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import Foundation
import ComposableArchitecture
import Kingfisher

struct MangaReadingViewState: Equatable {
    init(chapterID: UUID, chapterIndex: Double?, shoudSendUserToTheLastPage: Bool = false) {
        self.chapterID = chapterID
        self.chapterIndex = chapterIndex
        self.shouldSendUserToTheLastPage = shoudSendUserToTheLastPage
    }
    
    let chapterID: UUID
    let chapterIndex: Double?
    // this will be used, when user get to this chapter from the next following one
    let shouldSendUserToTheLastPage: Bool
    
    var pagesInfo: ChapterPagesInfo?
    var imagePrefetcher: ImagePrefetcher?
    @BindableState var currentPage: Int = 0
}

extension MangaReadingViewState {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.currentPage == rhs.currentPage &&
        lhs.pagesInfo == rhs.pagesInfo &&
        lhs.chapterIndex == rhs.chapterIndex &&
        lhs.chapterID == rhs.chapterID &&
        lhs.shouldSendUserToTheLastPage == rhs.shouldSendUserToTheLastPage
    }
}

enum MangaReadingViewAction: BindableAction {
    case userStartedReadingChapter
    case chapterPagesInfoFetched(Result<ChapterPagesInfo, AppError>)
    
    // MARK: - Actions to be hijacked in MangaFeature
    case userHitLastPage
    case userHitTheMostFirstPage
    case userLeftMangaReadingView
    
    case binding(BindingAction<MangaReadingViewState>)
}

struct MangaReadingViewEnvironment {
    var mangaClient: MangaClient
}

// swiftlint:disable:next line_length
let mangaReadingViewReducer = Reducer<MangaReadingViewState, MangaReadingViewAction, MangaReadingViewEnvironment> { state, action, env in
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
                    
                    if state.shouldSendUserToTheLastPage {
                        state.currentPage = chapterPagesInfo.dataSaverURLs.count - 1
                    }
                    
                    state.imagePrefetcher = ImagePrefetcher(
                        urls: chapterPagesInfo.dataSaverURLs,
                        options: [.memoryCacheExpiration(.days(1))]
                    )
                    
                    state.imagePrefetcher?.start()
                    
                    return .none

                case .failure(let error):
                    print("error on fetching chapterPagesInfo: \(error)")
                    return .none
            }
            
        case .binding(\.$currentPage):
            if state.currentPage == -1 {
                return Effect(value: MangaReadingViewAction.userHitTheMostFirstPage)
            } else if state.currentPage == state.pagesInfo?.dataSaverURLs.count {
                return Effect(value: MangaReadingViewAction.userHitLastPage)
            }
            
            return .none
            
        case .binding:
            return .none
            
        // MARK: - Actions to be hijacked in MangaFeature
        case .userHitLastPage:
            state.imagePrefetcher?.stop()
            return .none
            
        case .userHitTheMostFirstPage:
            state.imagePrefetcher?.stop()
            return .none
            
        case .userLeftMangaReadingView:
            state.imagePrefetcher?.stop()
            return .none
    }
}
.binding()
