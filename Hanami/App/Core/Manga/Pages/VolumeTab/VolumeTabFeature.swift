//
//  VolumeFeature.swift
//  Hanami
//
//  Created by Oleg on 26/05/2022.
//

import Foundation
import ComposableArchitecture

struct VolumeTabFeature: ReducerProtocol {
    struct State: Equatable, Identifiable {
        init(volume: MangaVolume, parentManga: Manga, online: Bool) {
            self.volume = volume
            chapterStates = .init(
                uniqueElements: volume.chapters.map {
                    ChapterFeature.State(chapter: $0, parentManga: parentManga, online: online)
                }
            )
        }
        
        let volume: MangaVolume
        let id = UUID()
        var chapterStates: IdentifiedArrayOf<ChapterFeature.State> = []
        
        var childrenChapterDetailsIDs: [UUID] {
            chapterStates.flatMap { $0.chapterDetailsList.map(\.id) }
        }
        
        var childrenChapterIndexes: [Int] {
            chapterStates.compactMap(\.chapter.chapterIndex).map(Int.init).removeDuplicates()
        }
    }
    
    enum Action {
        case chapterAction(id: UUID, action: ChapterFeature.Action)
        case userDeletedLastChapterInVolume
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .chapterAction(let chapterStateID, action: .downloaderAction(.chapterDeletionConfirmed)):
                // we compare it to 1 because this action will fire before chapter deletion from `chapterDetailsList`
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
        .forEach(\.chapterStates, action: /Action.chapterAction) {
            ChapterFeature()
        }
    }
}
