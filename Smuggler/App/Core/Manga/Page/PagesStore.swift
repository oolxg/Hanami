//
//  PageStore.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/07/2022.
//

import Foundation
import ComposableArchitecture

struct PagesState: Equatable {
    let manga: Manga
    let chaptersPerPage: Int
    
    init(manga: Manga, chaptersPerPage: Int) {
        self.manga = manga
        self.chaptersPerPage = chaptersPerPage
    }
    
    private(set) var splitIntoPagesVolumeTabStates: [[VolumeTabState]] = []
    var pagesCount: Int { splitIntoPagesVolumeTabStates.count }
    var volumeTabStatesOnCurrentPage: IdentifiedArrayOf<VolumeTabState> = []
    var currentPageIndex = 0 {
        willSet {
            let temp = volumeTabStatesOnCurrentPage
            volumeTabStatesOnCurrentPage = .init(uniqueElements: splitIntoPagesVolumeTabStates[newValue])
            splitIntoPagesVolumeTabStates[currentPageIndex] = Array(temp)
        }
    }
    
    // this lock to disable user on pressing on chapterDetails right after he changed page(this causes crashes)
    var lockPage = false
    var areVolumesLoaded = false
    var areVolumesFetchedWithError = false

    var shouldShowNothingToReadMessage: Bool {
        volumeTabStatesOnCurrentPage.isEmpty && areVolumesLoaded
    }
    // here we're splitting chapters(not ChapterDetails) into pages, `chaptersPerPage` per page
    mutating func handleLoadedVolumes(mangaVolumes: [MangaVolume]) {
        let allMangaChapters: [(chapter: Chapter, count: Int, volumeIndex: Double?)] = mangaVolumes.flatMap { volume in
            volume.chapters.map { (chapter: $0, count: volume.count, volumeIndex: volume.volumeIndex) }
        }

        for chaptersOnPage in allMangaChapters.chunked(into: chaptersPerPage) {
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

            splitIntoPagesVolumeTabStates.append(volumesOnPage.map { VolumeTabState(volume: $0) })
        }

        if !splitIntoPagesVolumeTabStates.isEmpty {
            volumeTabStatesOnCurrentPage = .init(uniqueElements: splitIntoPagesVolumeTabStates.first!)
        }
    }
}

enum PagesAction {
    case onAppear
    case volumesDownloaded(Result<VolumesContainer, AppError>)
    case changePage(newPageIndex: Int)
    case changePageAfterEffectCancellation(newPageIndex: Int)
    case unlockPage
    case volumeTabAction(volumeID: UUID, volumeAction: VolumeTabAction)
}

struct PagesEnvironment {
    let mangaClient: MangaClient
    let databaseClient: DatabaseClient
}

let pagesReducer: Reducer<PagesState, PagesAction, PagesEnvironment>  = .combine(
    volumeTabReducer.forEach(
        state: \.volumeTabStatesOnCurrentPage,
        action: /PagesAction.volumeTabAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            mangaClient: $0.mangaClient
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                if state.areVolumesLoaded && !state.areVolumesFetchedWithError {
                    return .none
                }
                
                return env.mangaClient.fetchMangaChapters(state.manga.id, nil, nil)
                    .receive(on: DispatchQueue.main)
                    .catchToEffect(PagesAction.volumesDownloaded)
                
            case .volumesDownloaded(let result):
                state.areVolumesLoaded = true
                switch result {
                    case .success(let response):
                        state.handleLoadedVolumes(mangaVolumes: response.volumes)
                        state.areVolumesFetchedWithError = false
                        
                        return .none
                        
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error)")
                        state.areVolumesFetchedWithError = true
                        
                        return .none
                }
                
            case .changePage(let newPageIndex):
                if newPageIndex != state.currentPageIndex && newPageIndex >= 0 && newPageIndex < state.pagesCount {
                    return .concatenate(
                        .cancel(id: ChapterState.CancelChapterFetch()),
                        Effect(value: PagesAction.changePageAfterEffectCancellation(newPageIndex: newPageIndex))
                    )
                }
                
                return .none
                
            case .changePageAfterEffectCancellation(let newPageIndex):
                state.lockPage = true
                state.currentPageIndex = newPageIndex
                return Effect(value: PagesAction.unlockPage)
                    .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                    .eraseToEffect()
                
            case .unlockPage:
                state.lockPage = false
                return .none
                
            case .volumeTabAction:
                return .none
        }
    }
)
