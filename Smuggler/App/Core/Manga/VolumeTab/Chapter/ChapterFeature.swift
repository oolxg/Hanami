//
//  ChapterFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 22/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct ChapterState: Equatable, Identifiable {
    // Chapter basic info
    let chapter: Chapter
    // we can have many 'chapterDetals' in one ChapterState because one chapter can be translated by different scanlation groups
    // here are each chapter with details
    var chapterDetails: IdentifiedArrayOf<ChapterDetails> = []
    var scanlationGroups: [UUID: ScanlationGroup] = [:]
    // Chapter UUID - Chapter pages
    var pages: [UUID: [UIImage]] = [:]
    
    var id: UUID {
        chapter.id
    }
}

enum ChapterAction {
    case loadChapterDetails
    case onTapGesture(chapter: ChapterDetails)
    case chapterDetailsDownloaded(result: Result<Response<ChapterDetails>, AppError>, chapterID: UUID)
    case scanlationGroupInfoFetched(result: Result<Response<ScanlationGroup>, AppError>, chapterID: UUID)
}

struct ChapterEnvironment {
    var downloadChapterInfo: (UUID, JSONDecoder) -> Effect<Response<ChapterDetails>, AppError>
    var fetchScanlationGroupInfo: (UUID, JSONDecoder) -> Effect<Response<ScanlationGroup>, AppError>
}

// About loading chapter pages

// we should load all pages when user opens chapter and only save it in caches directory
// when user open page, we immidiately get it from cache(or load it again if something happend

let chapterReducer = Reducer<ChapterState, ChapterAction, SystemEnvironment<ChapterEnvironment>> { state, action, env in
    switch action {
        case .loadChapterDetails:
            var effects: [Effect<ChapterAction, Never>] = []

            // if we fetched info about chapters, it means that pages info is downloaded too
            // (or externalURL, manga if to read on other webiste)
            if state.chapterDetails[id: state.chapter.id] == nil {
                // need this var because state is 'inout'
                let chapterID = state.chapter.id
                effects.append(
                    env.downloadChapterInfo(chapterID, env.decoder())
                        .receive(on: env.mainQueue())
                        .catchToEffect { ChapterAction.chapterDetailsDownloaded(result: $0, chapterID: chapterID) }
                )
            }
            
            for (i, otherChapterID) in state.chapter.others.enumerated() {
                if state.chapterDetails[id: otherChapterID] == nil {
                    effects.append(
                        env.downloadChapterInfo(otherChapterID, env.decoder())
                            .delay(for: .seconds(0.1 * Double(i + 1)), scheduler: env.mainQueue())
                            .receive(on: env.mainQueue())
                            .catchToEffect { ChapterAction.chapterDetailsDownloaded(
                                result: $0,
                                chapterID: otherChapterID
                            ) }
                    )
                }
            }

            return .merge(effects)
            
        case .onTapGesture:
            // this case is only for getting it in MangaFeature
            return .none

        case .chapterDetailsDownloaded(let result, let chapterID):
            switch result {
                case .success(let response):
                    state.chapterDetails.append(response.data)
                    
                    let allScanlationGroupIDs = state.chapterDetails
                        .compactMap { chapterDetails in
                            chapterDetails.relationships.first(where: { $0.type == .scanlationGroup }).map(\.id)
                        }
                    
                    var effects: [Effect<ChapterAction, Never>] = []
                    
                    for scanlationGroupID in allScanlationGroupIDs {
                        // if we already loaded info about scanlaton group -> skip
                        guard state.scanlationGroups[scanlationGroupID] == nil else { continue }
                        
                        effects.append(
                            env.fetchScanlationGroupInfo(scanlationGroupID, env.decoder())
                                .receive(on: env.mainQueue())
                                .catchToEffect {
                                    ChapterAction.scanlationGroupInfoFetched(
                                        result: $0,
                                        chapterID: chapterID
                                    )
                                }
                        )
                    }
                    
                    return .merge(effects)
                    
                case .failure(let error):
                    print("error on downloading chapter details, \(error)")
                    return .none
            }
            
        case .scanlationGroupInfoFetched(let result, let chapterID):
            switch result {
                case .success(let response):
                    state.scanlationGroups[chapterID] = response.data
                    return .none
                case .failure(let error):
                    print("Error on fetching scanlation group \(error)")
                    return .none
            }
    }
}
