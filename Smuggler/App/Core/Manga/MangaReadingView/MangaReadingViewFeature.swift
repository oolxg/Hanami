//
//  MangaReadingViewFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import Foundation
import ComposableArchitecture

struct MangaReadingViewState: Equatable {
    init(chapterID: UUID, chapterIndex: Double?) {
        self.chapterID = chapterID
        self.chapterIndex = chapterIndex
    }
    
    let chapterID: UUID
    let chapterIndex: Double?
    var pagesInfo: ChapterPagesInfo?
}

enum MangaReadingViewAction {
    case userStartedReadingChapter
    case chapterPagesInfoFetched(Result<ChapterPagesInfo, APIError>)
    
    // MARK: - Actions to be hijacked in MangaFeature
    case userTappedOnNextChapterButton
    case userTappedOnPreviousChapterButton
    case userLeftMangaReadingView
}

struct MangaReadingViewEnvironment {
    // UUID - chapter id
    var fetchChapterPagesInfo: (UUID) -> Effect<ChapterPagesInfo, APIError>
}

// swiftlint:disable:next line_length
let mangaReadingViewReducer = Reducer<MangaReadingViewState, MangaReadingViewAction, SystemEnvironment<MangaReadingViewEnvironment>> { state, action, env in
    switch action {
        case .userStartedReadingChapter:
            guard state.pagesInfo == nil else {
                return .none
            }
            
            return env.fetchChapterPagesInfo(state.chapterID)
                .receive(on: env.mainQueue())
                .catchToEffect(MangaReadingViewAction.chapterPagesInfoFetched)
            
        case .chapterPagesInfoFetched(let result):
            switch result {
                case .success(let chapterPagesInfo):
                    state.pagesInfo = chapterPagesInfo
                    return .none

                case .failure(let error):
                    print("error on fetching chapterPagesInfo: \(error)")
                    return .none
            }
            
        // MARK: - Actions to be hijacked in MangaFeature
        case .userTappedOnNextChapterButton:
            return .none
            
        case .userTappedOnPreviousChapterButton:
            return .none
            
        case .userLeftMangaReadingView:
            return .none
    }
}
