//
//  PageStore.swift
//  Hanami
//
//  Created by Oleg on 13/07/2022.
//

import Foundation
import ComposableArchitecture
import ModelKit

struct PagesFeature: Reducer {
    struct State: Equatable {
        // here we're splitting chapters(not ChapterDetails) into pages, `chaptersPerPage` per page
        init(manga: Manga, mangaVolumes: [MangaVolume], chaptersPerPage: Int, online: Bool) {
            // flattening all chapters into one array(but not forgetting to store 'volumeIndex'
            let allMangaChapters: [(chapter: Chapter, volumeIndex: Double?)] = mangaVolumes.flatMap { volume in
                volume.chapters.map { (chapter: $0, volumeIndex: volume.volumeIndex) }
            }
            
            // all chapters chunked into 'pages' - as they will be shown to user
            for chaptersOnPage in allMangaChapters.chunked(into: chaptersPerPage) {
                var volumesOnPage: [MangaVolume] = []
                var chaptersWithTheSameVolumeIndex: [(chapter: Chapter, volumeIndex: Double?)] = []
                
                // splitting chapters on same page according to their volumeIndex(if they have it)
                for chapter in chaptersOnPage {
                    if chaptersWithTheSameVolumeIndex.isEmpty
                        || chapter.volumeIndex == chaptersWithTheSameVolumeIndex.last!.volumeIndex {
                        chaptersWithTheSameVolumeIndex.append(chapter)
                    } else {
                        volumesOnPage.append(
                            MangaVolume(
                                chapters: chaptersWithTheSameVolumeIndex.map(\.chapter),
                                volumeIndex: chaptersWithTheSameVolumeIndex.first!.volumeIndex
                            )
                        )
                        
                        chaptersWithTheSameVolumeIndex = [chapter]
                    }
                    
                    // if chapter is the last chapter on page, we add it too
                    if chapter == chaptersOnPage.last! {
                        volumesOnPage.append(
                            MangaVolume(
                                chapters: chaptersWithTheSameVolumeIndex.map(\.chapter),
                                volumeIndex: chaptersWithTheSameVolumeIndex.first!.volumeIndex
                            )
                        )
                    }
                }
                
                splitIntoPagesVolumeTabStates.append(
                    volumesOnPage
                        .map { VolumeTabFeature.State(volume: $0, parentManga: manga, online: online) }
                        .asIdentifiedArray
                )
            }
            
            // if manga has at least on chapter, we show it on current(first) page
            // 'volumeTabStatesOnCurrentPage' - this is volumes, that gonna be displayed on page
            if !splitIntoPagesVolumeTabStates.isEmpty {
                volumeTabStatesOnCurrentPage = splitIntoPagesVolumeTabStates.first!
            }
        }
        
        // MARK: - init for offline usage
        init(manga: Manga, chaptersDetailsList: [ChapterDetails], chaptersPerPage: Int) {
            var volumesDict: [Double?: [ChapterDetails]] = [:]
            
            // splitting chapters into arrays according to 'chapter.attributes.volumeIndex'
            for chapterDetails in chaptersDetailsList {
                if volumesDict[chapterDetails.attributes.volumeIndex].isNil {
                    volumesDict[chapterDetails.attributes.volumeIndex] = [chapterDetails]
                } else {
                    volumesDict[chapterDetails.attributes.volumeIndex]!.append(chapterDetails)
                }
            }
            
            // storing chapters from previous step in arrays to be able to sort
            // them by 'chapter.attributes.volumeIndex'
            var volumes: [(volume: MangaVolume, chapters: [ChapterDetails])] = []
            
            for volumeIndex in volumesDict.keys {
                let volume = volumesDict[volumeIndex]!
                
                // need this because chapters with one 'chapterIndex' can be downloaded more than once - with different scanltaionGroups
                var cachedChapterDetails: [Double?: [ChapterDetails]] = [:]
                
                for chapter in volume {
                    if cachedChapterDetails[chapter.attributes.index].hasValue {
                        cachedChapterDetails[chapter.attributes.index]!.append(chapter)
                    } else {
                        cachedChapterDetails[chapter.attributes.index] = [chapter]
                    }
                }
                
                // sorting chapters desc by 'volumeIndex'
                let cachedChaptersAsList = cachedChapterDetails.map(\.value).sorted { lhs, rhs in
                    // all chapters in each array are having the same 'volumeIndex'
                    (lhs.first!.attributes.volumeIndex ?? .infinity) < (rhs.first!.attributes.volumeIndex ?? .infinity)
                }
                
                // 'Chapter' - it's simplified and compressed version of 'ChapterDetails'
                // it has only volumeIndex and IDs of all translations(scanlation group) of chapter
                var chapters: [Chapter] = []
                
                for chapterList in cachedChaptersAsList {
                    // here it doesn't matter which chapter ID will be set to "main" id (Chapter.id)
                    // and which to 'other'
                    var chapterList = chapterList
                    let chapter = chapterList.last!.asChapter
                    _ = chapterList.popLast()
                    
                    chapters.append(
                        Chapter(
                            index: chapter.index,
                            id: chapter.id,
                            others: chapterList.map(\.id)
                        )
                    )
                }
                
                // almost alway chapter has 'chapterIndex'
                // if not, most likely it's oneshot or sth, that should be at the beginning(in our pagination = in the end)
                chapters.sort { ($0.index ?? -1) > ($1.index ?? -1) }
                
                volumes.append((
                    volume: MangaVolume(chapters: chapters, volumeIndex: volumeIndex),
                    chapters: chaptersDetailsList.filter { chapterDetails in
                        chapters.contains { $0.id == chapterDetails.id }
                    })
                )
            }
            
            // sorting volmues by volumeIndex
            // typically the most fresh chapters stored in 'No Volume'(volumes w/o 'volumeIndex')
            // so we show this volume in the first place
            volumes.sort { ($0.volume.volumeIndex ?? .infinity) > ($1.volume.volumeIndex ?? .infinity) }
            
            // here we're shaped the data(volumes) as they were for online reading
            // and we can use another initializer
            self.init(
                manga: manga,
                mangaVolumes: volumes.map(\.volume),
                chaptersPerPage: chaptersPerPage,
                online: false
            )
        }
        
        private(set) var splitIntoPagesVolumeTabStates: [IdentifiedArrayOf<VolumeTabFeature.State>] = []
        var volumeTabStatesOnCurrentPage: IdentifiedArrayOf<VolumeTabFeature.State> = []
        
        var pagesCount: Int { splitIntoPagesVolumeTabStates.count }
        var currentPageIndex = 0 {
            willSet {
                let temp = volumeTabStatesOnCurrentPage
                volumeTabStatesOnCurrentPage = splitIntoPagesVolumeTabStates[newValue]
                splitIntoPagesVolumeTabStates[currentPageIndex] = temp
            }
        }
        
        // list of all UUIDs of first chapter options in manga
        var firstChapterOptionsIDs: [UUID] {
            var firstChapter: Chapter?
            
            for page in splitIntoPagesVolumeTabStates {
                for volumeState in page {
                    for chapterState in volumeState.chapterStates where (chapterState.chapter.index ?? .infinity) > 0 {
                        let otherChapterIndex = chapterState.chapter.index
                        if firstChapter.isNil || (firstChapter!.index ?? .infinity) > (otherChapterIndex ?? .infinity) {
                            firstChapter = chapterState.chapter
                        }
                    }
                }
            }
            
            guard let firstChapter else { return [] }
            
            return firstChapter.others + [firstChapter.id]
        }
    }
    
    
    enum Action {
        case pageIndexButtonTapped(newPageIndex: Int)
        case changePageAfterEffectCancellation(newPageIndex: Int)
        case userDeletedAllCachedChapters(parentMangaID: UUID)
        case volumeTabAction(volumeID: UUID, volumeAction: VolumeTabFeature.Action)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .pageIndexButtonTapped(let newIndex):
                guard newIndex != state.currentPageIndex, newIndex >= 0, newIndex < state.pagesCount else {
                    return .none
                }
                
                let chapterIDs = state.volumeTabStatesOnCurrentPage.flatMap(\.childrenChapterDetailsIDs)
                
                return .concatenate(
                    .merge(chapterIDs.map { .cancel(id: ChapterFeature.CancelChapterFetch(id: $0)) }),
                    
                    .run { await $0(.changePageAfterEffectCancellation(newPageIndex: newIndex)) }
                )
                
            case .changePageAfterEffectCancellation(let newPageIndex):
                state.currentPageIndex = newPageIndex
                return .none
                
            case .volumeTabAction(let volumeID, .userDeletedLastChapterInVolume(let mangaID)):
                state.volumeTabStatesOnCurrentPage.remove(id: volumeID)
                
                if state.volumeTabStatesOnCurrentPage.isEmpty && state.currentPageIndex != 0 {
                    state.currentPageIndex -= 1
                } else if state.volumeTabStatesOnCurrentPage.isEmpty {
                    return .run { send in
                        try await Task.sleep(seconds: 0.3)
                        await send(.userDeletedAllCachedChapters(parentMangaID: mangaID))
                    }
                }
                
                return .none
                
            case .userDeletedAllCachedChapters(let mangaID):
                mangaClient.deleteCoverArt(for: mangaID)
                return .none
                
            case .volumeTabAction:
                return .none
            }
        }
        .forEach(\.volumeTabStatesOnCurrentPage, action: /Action.volumeTabAction) {
            VolumeTabFeature()
        }
    }
}
