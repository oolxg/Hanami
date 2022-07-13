//
//  PageStore.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/07/2022.
//

import Foundation
import ComposableArchitecture

struct PagesState: Equatable {
    private var splittedIntoPagesVolumes: [[VolumeTabState]] = []
    var pagesCount: Int { splittedIntoPagesVolumes.count }
    var volumeTabStateToBeShown: IdentifiedArrayOf<VolumeTabState> = []
    var currentPage = 0 {
        willSet {
            let temp = volumeTabStateToBeShown
            volumeTabStateToBeShown = .init(uniqueElements: splittedIntoPagesVolumes[newValue])
            splittedIntoPagesVolumes[currentPage] = Array(temp)
        }
    }
    
    init(mangaVolumes: [MangaVolume], chaptersPerPage: Int) {
        // here we're splitting chapters(not ChapterDetails) into pages, `chaptersPerPage` per page
        var allChapters: [(chapter: Chapter, count: Int, volumeIndex: Double?)] = []
        
        for volume in mangaVolumes {
            allChapters.append(
                contentsOf: volume.chapters.map {
                    (chapter: $0, count: volume.count, volumeIndex: volume.volumeIndex)
                }
            )
        }
        
        for chapters in allChapters.chunked(into: chaptersPerPage) {
            var volumes: [MangaVolume] = []
            var chaptersToBeAdded: [(chapter: Chapter, count: Int, volumeIndex: Double?)] = []
            
            for chapter in chapters {
                if chaptersToBeAdded.isEmpty || chapter.volumeIndex == chaptersToBeAdded.last!.volumeIndex {
                    chaptersToBeAdded.append(chapter)
                } else {
                    volumes.append(
                        MangaVolume(
                            chapters: chaptersToBeAdded.map(\.chapter),
                            count: chaptersToBeAdded.first!.count,
                            volumeIndex: chaptersToBeAdded.first!.volumeIndex
                        )
                    )
                    
                    chaptersToBeAdded = [chapter]
                }
                
                if chapter == chapters.last! {
                    volumes.append(
                        MangaVolume(
                            chapters: chaptersToBeAdded.map(\.chapter),
                            count: chaptersToBeAdded.first!.count,
                            volumeIndex: chaptersToBeAdded.first!.volumeIndex
                        )
                    )
                }
            }
            
            splittedIntoPagesVolumes.append(volumes.map { VolumeTabState(volume: $0) })
        }
        
        if !splittedIntoPagesVolumes.isEmpty {
            volumeTabStateToBeShown = .init(uniqueElements: splittedIntoPagesVolumes.first!)
        }
    }
}

enum PageAction {
    case userTappedNextPageButton
    case userTappenOnLastPageButton
    case userTappedPreviousPageButton
    case userTappedOnFirstPageButton
    case volumeTabAction(volumeID: UUID, volumeAction: VolumeTabAction)
}

struct PageEnvironment {
    let mangaClient: MangaClient
    let databaseClient: DatabaseClient
}

let pagesReducer: Reducer<PagesState, PageAction, PageEnvironment>  = .combine(
    volumeTabReducer.forEach(
        state: \.volumeTabStateToBeShown,
        action: /PageAction.volumeTabAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            mangaClient: $0.mangaClient
        ) }
    ),
    Reducer { state, action, _ in
        switch action {
            case .userTappedNextPageButton:
                if state.currentPage + 1 < state.pagesCount {
                    state.currentPage += 1
                    return .cancel(id: ChapterState.CancelChapterFetch())
                }
                
                return .none
                
            case .userTappedPreviousPageButton:
                if state.currentPage > 0 {
                    state.currentPage -= 1
                    return .cancel(id: ChapterState.CancelChapterFetch())
                }
                
                return .none
                
            case .userTappedOnFirstPageButton:
                state.currentPage = 0
                return .cancel(id: ChapterState.CancelChapterFetch())
                
            case .userTappenOnLastPageButton:
                state.currentPage = state.pagesCount - 1
                return .cancel(id: ChapterState.CancelChapterFetch())
                
            case .volumeTabAction:
                return .none
                
        }
    }
)
