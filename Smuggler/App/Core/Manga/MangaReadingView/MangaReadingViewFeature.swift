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
    var pages: [UIImage?] = []
    // to track what images are downloading at the moment
    var loadingImagesNames: Set<String> = []
}

enum MangaReadingViewAction {
    case userStartedReadingChapter
    case chapterPagesInfoFetched(Result<ChapterPagesInfo, APIError>)
    case mangePagesDownloaded(result: Result<UIImage, APIError>, pageIndex: Int)
    case imageAppear(index: Int)
    case progressViewAppear(index: Int)
    
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
            if state.pagesInfo != nil {
                return .none
            }
            
            return env.fetchChapterPagesInfo(state.chapterID)
                .receive(on: env.mainQueue())
                .catchToEffect(MangaReadingViewAction.chapterPagesInfoFetched)
            
        case .chapterPagesInfoFetched(let result):
            switch result {
                case .success(let chapterPagesInfo):
                    state.pages = Array(repeating: nil, count: chapterPagesInfo.dataSaverURLs.count)
                    state.pagesInfo = chapterPagesInfo
                    
                    // we load only first 3 pages, otherwise it's very RAM- and CPU-expensive
                    return .merge(
                        chapterPagesInfo.dataSaverURLs.prefix(3).enumerated().map { i, url in
                            env.downloadImage(url)
                                .delay(for: .seconds(Double(i) * 0.5), scheduler: env.mainQueue())
                                .receive(on: env.mainQueue())
                                .catchToEffect {
                                    MangaReadingViewAction.mangePagesDownloaded(
                                        result: $0,
                                        pageIndex: i
                                    )
                                }
                        }
                    )
                    .cancellable(id: CancelPagesDownloading(), cancelInFlight: true)

                case .failure(let error):
                    print("error on fetching chapterPagesInfo: \(error)")
                    return .none
            }
            
        case .mangePagesDownloaded(let result, let index):
            switch result {
                case .success(let image):
                    guard index < state.pages.count else {
                        fatalError(
                            "Somehow order of page is more then reserved capacity: \(index), \(state.pages.count)"
                        )
                    }
                    
                    state.loadingImagesNames.remove(
                        state.pagesInfo!.chapter.dataSaver[index]
                    )
                    
                    state.pages[index] = image

                    return .none
                    
                case .failure(let error):
                    print("error on loading image: \(error)")
                    return .none
            }
            
        case .progressViewAppear(var index):
            // first 3 pages are loading by default
            if index <= 2 {
                return .none
            }
            
            index -= 1
            
            if state.loadingImagesNames.contains(state.pagesInfo!.chapter.dataSaver[index]) {
                // it means we're already loading this image
                return .none
            }
            
            state.loadingImagesNames.insert(state.pagesInfo!.chapter.dataSaver[index])
            
            return env.downloadImage(state.pagesInfo!.dataSaverURLs[index])
                .receive(on: env.mainQueue())
                .catchToEffect {
                    MangaReadingViewAction.mangePagesDownloaded(
                        result: $0,
                        pageIndex: index
                    )
                }
                .cancellable(id: CancelPagesDownloading(), cancelInFlight: true)
            
        case .imageAppear(let index):
            // TODO: - Make image save in cache and delete from state.images after it disappears
            guard let pagesInfo = state.pagesInfo else {
                print("Somehow we lost pages info...")
                return .none
            }
            
            let nextImageIndex = index + 1
            // if we have image with index two, we have to load image with index 3 and so on
            guard index >= 2, nextImageIndex < pagesInfo.dataSaverURLs.count, state.pages[nextImageIndex] == nil else {
                // first 3 images [0, 1, 2] we're loading by default in 'chapterPagesInfoFetched'
                return .none
            }
            
            state.loadingImagesNames.insert(state.pagesInfo!.chapter.dataSaver[nextImageIndex])
            
            return env.downloadImage(pagesInfo.dataSaverURLs[nextImageIndex])
                .receive(on: env.mainQueue())
                .catchToEffect {
                    MangaReadingViewAction.mangePagesDownloaded(
                        result: $0,
                        pageIndex: nextImageIndex
                    )
                }
                .cancellable(id: CancelPagesDownloading(), cancelInFlight: true)
            
        // MARK: - Actions to be hijacked in MangaFeature
        case .userTappedOnNextChapterButton:
            return .cancel(id: CancelPagesDownloading())
            
        case .userTappedOnPreviousChapterButton:
            return .cancel(id: CancelPagesDownloading())
            
        case .userLeftMangaReadingView:
            return .cancel(id: CancelPagesDownloading())
    }
}
