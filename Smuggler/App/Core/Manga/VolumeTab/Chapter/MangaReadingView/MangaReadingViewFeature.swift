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
    var pagesInfo: ChapterPagesInfo?
    var images: [UIImage?] = []
}

enum MangaReadingViewAction {
    case userStartedReadingChapter
    case chapterPagesInfoFetched(Result<ChapterPagesInfo, APIError>)
    case imageDownloaded(result: Result<UIImage, APIError>, imageName: String, order: Int)
    case imageAppear(index: Int)
    
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
    struct CancelPagesDownloading: Hashable { }
    switch action {
        case .userStartedReadingChapter:
            guard state.pagesInfo == nil else { return .none }
            
            return env.fetchChapterPagesInfo(state.chapterID)
                .catchToEffect(MangaReadingViewAction.chapterPagesInfoFetched)
            
        case .chapterPagesInfoFetched(let result):
            switch result {
                case .success(let chapterPagesInfo):
                    state.images = Array(repeating: nil, count: chapterPagesInfo.dataSaverURLs.count)
                    state.pagesInfo = chapterPagesInfo
                    
                    // we load only first 3 pages, otherwise it's very RAM- and CPU-expensive
                    return .merge(
                        chapterPagesInfo.dataSaverURLs.prefix(3).enumerated().map { i, url in
                            env.downloadImage(url)
                                .delay(for: .seconds(Double(i) * 0.5), scheduler: env.mainQueue())
                                .receive(on: env.mainQueue())
                                .catchToEffect {
                                    MangaReadingViewAction.imageDownloaded(
                                        result: $0,
                                        imageName: chapterPagesInfo.chapter.dataSaver[i],
                                        order: i
                                    )
                                }
                        }
                    )
                    .cancellable(id: CancelPagesDownloading())

                case .failure(let error):
                    print("error on fetching chapterPagesInfo: \(error)")
                    return .none
            }
            
        case .imageDownloaded(let result, let imageName, let order):
            switch result {
                case .success(let image):
                    print("loaded: \(order)")
                    guard order < state.images.count else {
                        fatalError(
                            "Somehow order of page is more then reserved capacity: \(order), \(state.images.count)"
                        )
                    }
                    state.images[order] = image

                    return .none
                    
                case .failure(let error):
                    print("error on loading image: \(error)")
                    return .none
            }
            
        case .imageAppear(let index):
            // TODO: - Make image save in cache and delete from state.images after it disappears
            guard let pagesInfo = state.pagesInfo else {
                fatalError("Somehow we lost pages info...")
            }
            
            let nextImageIndex = index + 1
            // if we have image with index two, we have to load image with index 3 and so on
            guard index > 1, nextImageIndex < pagesInfo.dataSaverURLs.count else {
                // first 3 images [0, 1, 2] we're loading by default in 'chapterPagesInfoFetched'
                return .none
            }
            
            if state.images[nextImageIndex] != nil {
                // means we already loaded this page
                return .none
            }
            
            if nextImageIndex < pagesInfo.dataSaverURLs.count {
                return env.downloadImage(pagesInfo.dataSaverURLs[nextImageIndex])
                    .receive(on: env.mainQueue())
                    .catchToEffect {
                        MangaReadingViewAction.imageDownloaded(
                            result: $0,
                            imageName: pagesInfo.chapter.dataSaver[nextImageIndex],
                            order: nextImageIndex
                        )
                    }
            } else {
                return .none
            }
            
        // MARK: - Actions to be hijacked in MangaFeature
        case .userTappedOnNextChapterButton:
            return .none
            
        case .userTappedOnPreviousChapterButton:
            return .none
            
        case .userLeftMangaReadingView:
            return .cancel(id: CancelPagesDownloading())
    }
}
