//
//  VolumeFeature.swift
//  Hanami
//
//  Created by Oleg on 26/05/2022.
//

import Foundation
import ComposableArchitecture

struct VolumeTabState: Equatable, Identifiable {
    init(volume: MangaVolume, parentManga: Manga, online: Bool) {
        self.volume = volume
        chapterStates = .init(
            uniqueElements: volume.chapters.map {
                ChapterState(chapter: $0, parentManga: parentManga, online: online)
            }
        )
    }
    
    let volume: MangaVolume
    let id = UUID()
    var chapterStates: IdentifiedArrayOf<ChapterState> = []
    
    var childrenChapterDetailsIDs: [UUID] {
        chapterStates.flatMap { $0.chapterDetailsList.map(\.id) }
    }
    
    var childrenChapterIndexes: [Int] {
        chapterStates.compactMap(\.chapter.chapterIndex).map(Int.init).removeDuplicates()
    }
}


enum VolumeTabAction {
    case chapterAction(id: UUID, action: ChapterAction)
    case userDeletedLastChapterInVolume
}

struct VolumeTabEnvironment {
    let databaseClient: DatabaseClient
    let imageClient: ImageClient
    let cacheClient: CacheClient
    let mangaClient: MangaClient
    let hudClient: HUDClient
}

// this reducer is only to store chapters more conveniently
let volumeTabReducer: Reducer<VolumeTabState, VolumeTabAction, VolumeTabEnvironment> = .combine(
    chapterReducer.forEach(
        state: \.chapterStates,
        action: /VolumeTabAction.chapterAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            imageClient: .live,
            cacheClient: $0.cacheClient,
            mangaClient: $0.mangaClient,
            hudClient: $0.hudClient
        ) }
    ),
    Reducer { state, action, _ in
        switch action {
            case .chapterAction(let chapterStateID, action: .chapterDeletionConfirmed):
                if state.chapterStates[id: chapterStateID]!.chapterDetailsList.isEmpty {
                    state.chapterStates.remove(id: chapterStateID)
                    
                    if state.chapterStates.isEmpty {
                        return .task { .userDeletedLastChapterInVolume }
                    }
                }
                
                return .none
                
            // to be hijacked inside pagesReducer
            case .userDeletedLastChapterInVolume:
                return .none
                
            case .chapterAction:
                return .none
        }
    }
)
