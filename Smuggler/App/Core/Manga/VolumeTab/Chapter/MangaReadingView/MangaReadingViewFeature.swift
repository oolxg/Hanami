//
//  MangaReadingViewFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct MangaReadingViewState: Equatable {
    init(chapterID: UUID) {
        self.chapterID = chapterID
//        images = Array(repeating: nil, count: pagesInfo.dataSaverURLs.count)
    }
    
    let chapterID: UUID
    var chapterPagesInfo: ChapterPagesInfo?
    var images: [UIImage?] = []
}

enum MangaReadingViewAction {
    case onAppear
    case chapterPagesInfoFetched(Result<ChapterPagesInfo, APIError>)
    case imageDownloaded(result: Result<UIImage, APIError>, order: Int)
}

struct MangaReadingViewEnvironment {
    // UUID - chapter id
    var fetchChapterPagesInfo: (UUID) -> Effect<ChapterPagesInfo, APIError>
}

// swiftlint:disable:next line_length
let mangaReadingViewReducer = Reducer<MangaReadingViewState, MangaReadingViewAction, SystemEnvironment<MangaReadingViewEnvironment>> { state, action, env in
    switch action {
        case .onAppear:
            return env.fetchChapterPagesInfo(state.chapterID)
                .receive(on: env.mainQueue())
                .catchToEffect(MangaReadingViewAction.chapterPagesInfoFetched)
            
        case .imageDownloaded(let result, let order):
            switch result {
                case .success(let image):
                    return .none
                case .failure(let error):
                    print("error on loading image: \(error)")
                    return .none
            }
            
        case .chapterPagesInfoFetched(let result):
            switch result {
                case .success(let chapterPagesInfo):
                    state.chapterPagesInfo = chapterPagesInfo
                    return .none
                case .failure(let error):
                    print("error on fetching chapterPagesInfo: \(error)")
                    return .none
            }
    }
}
