//
//  VolumeFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 26/05/2022.
//

import Foundation
import ComposableArchitecture

struct VolumeTabState: Equatable {
    init(volume: MangaVolume) {
        self.volume = volume
        chapterStates = .init(
            uniqueElements: volume.chapters.map { ChapterState(chapter: $0) }
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

struct VolumeTabEnvironment { }

// this reducer is only to store chapters more coniviniently
let volumeTabReducer: Reducer<VolumeTabState, VolumeTabAction, VolumeTabEnvironment> = .combine(
    chapterReducer.forEach(
        state: \.chapterStates,
        action: /VolumeTabAction.chapterAction,
        environment: { _ in  .init(
            downloadChapterInfo: downloadChapterInfo,
            fetchScanlationGroupInfo: fetchScanlationGroupInfo
        ) }
    )
)
