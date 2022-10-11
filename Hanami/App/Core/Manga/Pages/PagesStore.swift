//
//  PageStore.swift
//  Hanami
//
//  Created by Oleg on 13/07/2022.
//

import Foundation
import ComposableArchitecture

struct PagesFeature: ReducerProtocol {
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
                    volumesOnPage.map { VolumeTabFeature.State(volume: $0, parentManga: manga, online: online) }
                )
            }
            
            // if manga has at least on chapter, we show it on current(first) page
            // 'volumeTabStatesOnCurrentPage' - this is volumes, that gonna be displayed on page
            if !splitIntoPagesVolumeTabStates.isEmpty {
                volumeTabStatesOnCurrentPage = .init(uniqueElements: splitIntoPagesVolumeTabStates.first!)
            }
        }
        
        // MARK: - init for offline usage
        init(manga: Manga, chaptersDetailsList: [ChapterDetails], chaptersPerPages: Int) {
            var volumesDict: [Double?: [ChapterDetails]] = [:]
            
            // splitting chapters into arrays according to 'chapter.attributes.volumeIndex'
            for chapterDetails in chaptersDetailsList {
                if volumesDict[chapterDetails.attributes.volumeIndex] == nil {
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
                    if cachedChapterDetails[chapter.attributes.chapterIndex] != nil {
                        cachedChapterDetails[chapter.attributes.chapterIndex]!.append(chapter)
                    } else {
                        cachedChapterDetails[chapter.attributes.chapterIndex] = [chapter]
                    }
                }
                
                // sorting chapters desc by 'volumeIndex'
                let cachedChaptersAsList = cachedChapterDetails.map(\.value).sorted { lhs, rhs in
                    // all chapters in each array are having the same 'volumeIndex'
                    (lhs.first!.attributes.volumeIndex ?? 9999) < (rhs.first!.attributes.volumeIndex ?? 9999)
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
                            chapterIndex: chapter.chapterIndex,
                            id: chapter.id,
                            others: chapterList.map(\.id)
                        )
                    )
                }
                
                // almost alway chapter has 'chapterIndex'
                // if not, most likely it's oneshot or sth, that should be at the beginning(in our pagination = in the end)
                chapters.sort { ($0.chapterIndex ?? -1) > ($1.chapterIndex ?? -1) }
                
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
            volumes.sort { ($0.volume.volumeIndex ?? 9999) > ($1.volume.volumeIndex ?? 9999) }
            
            // here we're shaped the data(volumes) as they were for online reading
            // and we can use another initializer
            self.init(
                manga: manga,
                mangaVolumes: volumes.map(\.volume),
                chaptersPerPage: chaptersPerPages,
                online: false
            )
        }
        
        private(set) var splitIntoPagesVolumeTabStates: [[VolumeTabFeature.State]] = []
        var volumeTabStatesOnCurrentPage: IdentifiedArrayOf<VolumeTabFeature.State> = []
        
        var pagesCount: Int { splitIntoPagesVolumeTabStates.count }
        var currentPageIndex = 0 {
            willSet {
                let temp = volumeTabStatesOnCurrentPage
                volumeTabStatesOnCurrentPage = .init(uniqueElements: splitIntoPagesVolumeTabStates[newValue])
                splitIntoPagesVolumeTabStates[currentPageIndex] = Array(temp)
            }
        }
        
        // this lock to disable user on pressing on chapterDetails right after he changed page(this causes crashes)
        var lockPage = false
    }
    
    
    enum Action {
        case changePage(newPageIndex: Int)
        case changePageAfterEffectCancellation(newPageIndex: Int)
        case unlockPage
        case volumeTabAction(volumeID: UUID, volumeAction: VolumeTabFeature.Action)
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
                case .changePage(let newIndex):
                    guard newIndex != state.currentPageIndex, newIndex >= 0, newIndex < state.pagesCount else {
                        return .none
                    }
                    
                    let chapterIDs = state.volumeTabStatesOnCurrentPage.flatMap(\.childrenChapterDetailsIDs)
                    
                    return .concatenate(
                        .cancel(ids: chapterIDs.map { ChapterFeature.CancelChapterFetch(id: $0) }),
                        
                        .task { .changePageAfterEffectCancellation(newPageIndex: newIndex) }
                    )
                    
                case .changePageAfterEffectCancellation(let newPageIndex):
                    state.lockPage = true
                    state.currentPageIndex = newPageIndex
                    return .task { .unlockPage }
                        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                        .eraseToEffect()
                    
                case .unlockPage:
                    state.lockPage = false
                    return .none
                    
                case .volumeTabAction(let volumeID, .userDeletedLastChapterInVolume):
                    state.volumeTabStatesOnCurrentPage.remove(id: volumeID)
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
