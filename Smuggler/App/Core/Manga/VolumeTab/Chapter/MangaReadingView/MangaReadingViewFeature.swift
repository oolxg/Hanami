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
    init(chapterID: UUID, chapterIndex: Double?) {
        self.chapterID = chapterID
        self.chapterIndex = chapterIndex
    }
    
    let chapterID: UUID
    let chapterIndex: Double?
    var chapterPagesInfo: ChapterPagesInfo?
    var images: [UIImage?] = []
}

enum MangaReadingViewAction {
    case onAppear
    case chapterPagesInfoFetched(Result<ChapterPagesInfo, APIError>)
    case imageDownloaded(result: Result<UIImage, APIError>, order: Int)
    
    // MARK: - Actions to be hijacked in MangaFeature
    case userTappedOnNextChapterButton
    case userTappedOnPreviousChapterButton
}

struct MangaReadingViewEnvironment {
    // UUID - chapter id
    var fetchChapterPagesInfo: (UUID) -> Effect<ChapterPagesInfo, APIError>
}

// swiftlint:disable:next line_length
let mangaReadingViewReducer = Reducer<MangaReadingViewState, MangaReadingViewAction, SystemEnvironment<MangaReadingViewEnvironment>> { state, action, env in
    switch action {
        case .onAppear:
            guard state.chapterPagesInfo == nil else { return .none }
            
            return env.fetchChapterPagesInfo(state.chapterID)
                .catchToEffect(MangaReadingViewAction.chapterPagesInfoFetched)
            
        case .chapterPagesInfoFetched(let result):
            switch result {
                case .success(let chapterPagesInfo):
                    state.images.resize(chapterPagesInfo.dataSaverURLs.count, fillWith: nil)
                    state.chapterPagesInfo = chapterPagesInfo
                    
                    return .merge(
                        chapterPagesInfo.dataSaverURLs.enumerated().map { i, url in
                            env.downloadImage(url)
                                .receive(on: env.mainQueue())
                                .catchToEffect { MangaReadingViewAction.imageDownloaded(result: $0, order: i) }
                        }
                    )
                case .failure(let error):
                    print("error on fetching chapterPagesInfo: \(error)")
                    return .none
            }
            
        case .imageDownloaded(let result, let order):
            switch result {
                case .success(let image):
                    state.images.insert(image, at: order)
                    return .none
                case .failure(let error):
                    print("error on loading image: \(error)")
                    return .none
            }

        // MARK: - Actions to be hijacked in MangaFeature
        case .userTappedOnNextChapterButton:
            return .none
            
        case .userTappedOnPreviousChapterButton:
            return .none
            
    }
}
