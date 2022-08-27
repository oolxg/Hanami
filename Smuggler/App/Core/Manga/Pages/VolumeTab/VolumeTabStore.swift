//
//  VolumeFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 26/05/2022.
//

import Foundation
import ComposableArchitecture

struct VolumeTabState: Equatable {
    init(volume: MangaVolume, isOnline: Bool) {
        self.volume = volume
        chapterStates = .init(
            uniqueElements: volume.chapters.map { ChapterState(chapter: $0, isOnline: isOnline) }
        )
    }
    
    let volume: MangaVolume
    var chapterStates: IdentifiedArrayOf<ChapterState> = []
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
    let mangaClient: MangaClient
    let cacheClient: CacheClient
}

// this reducer is only to store chapters more conveniently
let volumeTabReducer: Reducer<VolumeTabState, VolumeTabAction, VolumeTabEnvironment> = .combine(
    chapterReducer.forEach(
        state: \.chapterStates,
        action: /VolumeTabAction.chapterAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            mangaClient: $0.mangaClient,
            cacheClient: $0.cacheClient
        ) }
    )
)
