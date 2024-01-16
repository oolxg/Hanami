//
//  VolumeFeature.swift
//  Hanami
//
//  Created by Oleg on 26/05/2022.
//

import Foundation
import ComposableArchitecture
import ModelKit

struct VolumeTabFeature: Reducer {
    struct State: Equatable, Identifiable {
        init(volume: MangaVolume, parentManga: Manga, online: Bool) {
            self.volume = volume
            chapterStates = volume.chapters
                .map { ChapterFeature.State(chapter: $0, parentManga: parentManga, online: online) }
                .asIdentifiedArray
        }
        
        let volume: MangaVolume
        let id = UUID()
        var chapterStates: IdentifiedArrayOf<ChapterFeature.State> = []
        
        var childrenChapterDetailsIDs: [UUID] {
            chapterStates.flatMap { $0.chapterDetailsList.map(\.id) }
        }
        
        var childrenChapterIndexes: [Int] {
            chapterStates.compactMap(\.chapter.index).map(Int.init).removeDuplicates()
        }
    }
    
    enum Action {
        case chapterAction(id: UUID, action: ChapterFeature.Action)
        case userDeletedLastChapterInVolume(mangaID: UUID)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .chapterAction(let chapterStateID, action: .downloaderAction(.chapterDeletionConfirmed)):
                if state.chapterStates[id: chapterStateID]!.chapterDetailsList.isEmpty {
                    state.chapterStates.remove(id: chapterStateID)
                    
                    if state.chapterStates.isEmpty {
                        let mangaID = state.chapterStates[id: chapterStateID]!.parentManga.id
                        return .run { await $0(.userDeletedLastChapterInVolume(mangaID: mangaID)) }
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
        .forEach(\.chapterStates, action: /Action.chapterAction) {
            ChapterFeature()
        }
    }
}
