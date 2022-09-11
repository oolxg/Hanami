//
//  VolumeFeature.swift
//  Hanami
//
//  Created by Oleg on 26/05/2022.
//

import Foundation
import ComposableArchitecture

struct VolumeTabState: Equatable {
    init(volume: MangaVolume, parentManga: Manga, isOnline: Bool) {
        self.volume = volume
        chapterStates = .init(
            uniqueElements: volume.chapters.map {
                ChapterState(chapter: $0, parentManga: parentManga, isOnline: isOnline)
            }
        )
    }
    
    let volume: MangaVolume
    var chapterStates: IdentifiedArrayOf<ChapterState> = []
    
    var childrenChapterIDs: [UUID] {
        chapterStates.flatMap { $0.chapterDetailsList.map(\.id) }
    }
    
    var childrenChapterIndexes: [Int] {
        chapterStates.compactMap(\.chapter.chapterIndex).map(Int.init).removeDuplicates()
    }
}

extension VolumeTabState: Identifiable {
    var id: UUID {
        volume.id
    }
}

enum VolumeTabAction {
    case chapterAction(id: UUID, action: ChapterAction)
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
    )
)
