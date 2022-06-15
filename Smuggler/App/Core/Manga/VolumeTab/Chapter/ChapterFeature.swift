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
    // Chapter UUID - Info about chapter pages
    var pagesInfo: [UUID: ChapterPagesInfo] = [:]
    // Chapter UUID - Chapter pages
    var pages: [UUID: [UIImage]] = [:]
    
    var id: UUID {
        chapter.id
    }
}

enum ChapterAction {
    case onAppear
    case mangaPageInfoDownloaded(result: Result<ChapterPagesInfo, APIError>, chapterID: UUID)
    case chapterDetailsDownloaded(result: Result<Response<ChapterDetails>, APIError>, chapterID: UUID)
    case scanlationGroupInfoFetched(result: Result<Response<ScanlationGroup>, APIError>, chapterID: UUID)
}

struct ChapterEnvironment {
    var downloadPagesInfo: (UUID) -> Effect<ChapterPagesInfo, APIError>
    var downloadChapterInfo: (UUID, JSONDecoder) -> Effect<Response<ChapterDetails>, APIError>
    var fetchScanlationGroupInfo: (UUID, JSONDecoder) -> Effect<Response<ScanlationGroup>, APIError>
}

// About loading chapter pages

// we should load all pages when user opens chapter and only save it in caches directory
// when user open page, we immidiately get it from cache(or load it again if something happend

let chapterReducer = Reducer<ChapterState, ChapterAction, SystemEnvironment<ChapterEnvironment>> { state, action, env in
    switch action {
        case .onAppear:
            guard state.pagesInfo[state.chapter.id] == nil else {
                return .none
            }

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
            
            for otherChapterID in state.chapter.others {
                if state.chapterDetails[id: otherChapterID] == nil {
                    effects.append(
                        env.downloadChapterInfo(otherChapterID, env.decoder())
                            .receive(on: env.mainQueue())
                            .catchToEffect { ChapterAction.chapterDetailsDownloaded(
                                result: $0,
                                chapterID: otherChapterID
                            ) }
                    )
                }
            }

            return .merge(effects)

        case .mangaPageInfoDownloaded(let result, let chapterID):
            switch result {
                case .success(let pagesInfo):
                    state.pagesInfo[chapterID] = pagesInfo
                    return .none
                case .failure(let error):
                    print("Error on downloading page info \(error)")
                    return .none
            }
            
        case .chapterDetailsDownloaded(let result, let chapterID):
            switch result {
                case .success(let response):
                    state.chapterDetails.append(response.data)
                    
                    var effects: [Effect<ChapterAction, Never>] = []
                    
                    // swiftlint:disable:next force_unwrapping
                    if state.chapterDetails[id: chapterID]!.attributes.externalURL == nil {
                        effects.append(
                            env.downloadPagesInfo(chapterID)
                                .receive(on: env.mainQueue())
                                .catchToEffect { ChapterAction.mangaPageInfoDownloaded(
                                    result: $0,
                                    chapterID: chapterID
                                ) }
                            )
                    }
                    
                    let scanlationGroupIDs = state.chapterDetails
                        .map { chapterDetails in
                            chapterDetails.relationships.first(where: { $0.type == .scanlationGroup }).map(\.id)
                        }
                        .compactMap { $0 }
                    
                    effects.append(contentsOf: scanlationGroupIDs.map { id in
                        env.fetchScanlationGroupInfo(id, env.decoder())
                            .receive(on: env.mainQueue())
                            .catchToEffect { ChapterAction.scanlationGroupInfoFetched(
                                result: $0,
                                chapterID: chapterID)
                            }
                        }
                    )
                    
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
