//
//  PageStore.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/07/2022.
//

import Foundation
import ComposableArchitecture

struct PagesState: Equatable {
    private var splittedIntoPagesVolumeTabStates: [[VolumeTabState]] = []
    var pagesCount: Int { splittedIntoPagesVolumeTabStates.count }
    // represents all volumes on page
    var volumeTabStatesOnCurrentPage: IdentifiedArrayOf<VolumeTabState> = []
    var currentPageIndex = 0 {
        willSet {
            let temp = volumeTabStatesOnCurrentPage
            volumeTabStatesOnCurrentPage = .init(uniqueElements: splittedIntoPagesVolumeTabStates[newValue])
            splittedIntoPagesVolumeTabStates[currentPageIndex] = Array(temp)
        }
    }

    // here we're splitting chapters(not ChapterDetails) into pages, `chaptersPerPage` per page
    init(mangaVolumes: [MangaVolume], chaptersPerPage: Int) {
        let allMangaChapters: [(chapter: Chapter, count: Int, volumeIndex: Double?)] = mangaVolumes.flatMap { volume in
            volume.chapters.map { (chapter: $0, count: volume.count, volumeIndex: volume.volumeIndex) }
        }
        
        var chunkedChapters = allMangaChapters.chunked(into: chaptersPerPage)

        // This 'if' is here because of strange LazyVStack animations
        // if there're only few chapters on page, then on page change we're getting bad animations
        // so the next lines of code checking if last page contains 5 or less chapters and if yes,
        // we merge it with penultimate page
        if chunkedChapters.count > 1 && chunkedChapters.last!.count <= 5 {
            let lastPageChunkedChapters = chunkedChapters.last!
            chunkedChapters.removeLast()
            chunkedChapters[chunkedChapters.count - 1].append(contentsOf: lastPageChunkedChapters)
        }
        
        for chaptersOnPage in chunkedChapters {
            var volumesOnPage: [MangaVolume] = []
            var chaptersToBeAdded: [(chapter: Chapter, count: Int, volumeIndex: Double?)] = []
            
            for chapter in chaptersOnPage {
                if chaptersToBeAdded.isEmpty || chapter.volumeIndex == chaptersToBeAdded.last!.volumeIndex {
                    chaptersToBeAdded.append(chapter)
                } else {
                    volumesOnPage.append(
                        MangaVolume(
                            chapters: chaptersToBeAdded.map(\.chapter),
                            count: chaptersToBeAdded.first!.count,
                            volumeIndex: chaptersToBeAdded.first!.volumeIndex
                        )
                    )
                    
                    chaptersToBeAdded = [chapter]
                }
                
                if chapter == chaptersOnPage.last! {
                    volumesOnPage.append(
                        MangaVolume(
                            chapters: chaptersToBeAdded.map(\.chapter),
                            count: chaptersToBeAdded.first!.count,
                            volumeIndex: chaptersToBeAdded.first!.volumeIndex
                        )
                    )
                }
            }
            
            splittedIntoPagesVolumeTabStates.append(volumesOnPage.map { VolumeTabState(volume: $0) })
        }
        
        if !splittedIntoPagesVolumeTabStates.isEmpty {
            volumeTabStatesOnCurrentPage = .init(uniqueElements: splittedIntoPagesVolumeTabStates.first!)
        }
    }
}

enum PageAction {
    case changePage(newPageIndex: Int)
    case volumeTabAction(volumeID: UUID, volumeAction: VolumeTabAction)
}

struct PageEnvironment {
    let mangaClient: MangaClient
    let databaseClient: DatabaseClient
}

let pagesReducer: Reducer<PagesState, PageAction, PageEnvironment>  = .combine(
    volumeTabReducer.forEach(
        state: \.volumeTabStatesOnCurrentPage,
        action: /PageAction.volumeTabAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            mangaClient: $0.mangaClient
        ) }
    ),
    Reducer { state, action, _ in
        switch action {
            case .changePage(let newPageIndex):
                if newPageIndex >= 0 && newPageIndex < state.pagesCount {
                    state.currentPageIndex = newPageIndex
                    return .cancel(id: ChapterState.CancelChapterFetch())
                }
                
                return .none
                
            case .volumeTabAction:
                return .none
        }
    }
)
