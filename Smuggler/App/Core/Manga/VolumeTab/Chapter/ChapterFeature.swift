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
    
    var id: UUID {
        chapter.id
    }
    
    @BindableState var areChaptersShown = false
    
    var loadingChapterDetailsCount = 0
    var areAllChapterDetailsDownloaded: Bool {
        loadingChapterDetailsCount == 0
    }
}

enum ChapterAction: BindableAction {
    case userTappedOnChapter
    case userTappedOnChapterDetails(chapter: ChapterDetails)
    case showChapterDetailsAfterDelayIfNeeded
    case chapterDetailsDownloaded(result: Result<Response<ChapterDetails>, AppError>, chapterID: UUID)
    case scanlationGroupInfoFetched(result: Result<Response<ScanlationGroup>, AppError>, chapterID: UUID)
    
    case binding(BindingAction<ChapterState>)
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
        case .userTappedOnChapter:
            var effects: [Effect<ChapterAction, Never>] = []

            // if we fetched info about chapters, it means that pages info is downloaded too
            // (or externalURL, manga if to read on other webiste)
            if state.chapterDetails[id: state.chapter.id] == nil {
                state.loadingChapterDetailsCount += 1
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
                    state.loadingChapterDetailsCount += 1
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
            
            if effects.isEmpty {
                state.areChaptersShown.toggle()
            }

            return effects.isEmpty ? .none : .merge(effects)

        case .binding:
            return .none
            
        case .userTappedOnChapterDetails:
            // this case is only for getting it in MangaFeature
            return .none

        case .chapterDetailsDownloaded(let result, let chapterID):
            state.loadingChapterDetailsCount -= 1
            switch result {
                case .success(let response):
                    state.chapterDetails.append(response.data)
                    
                    guard let scanlationGroupID = response.data.scanltaionGroupID else {
                        state.areChaptersShown.toggle()
                        return .none
                    }
                    
                    return .merge(
                        Effect(value: ChapterAction.showChapterDetailsAfterDelayIfNeeded)
                            .delay(for: .seconds(0.2), scheduler: env.mainQueue())
                            .eraseToEffect(),
                        
                        env.fetchScanlationGroupInfo(scanlationGroupID, env.decoder())
                            .receive(on: env.mainQueue())
                            .catchToEffect {
                                ChapterAction.scanlationGroupInfoFetched(
                                    result: $0,
                                    chapterID: response.data.id
                                )
                            }
                    )
                    
                case .failure(let error):
                    print("error on downloading chapter details, \(error)")
                    return Effect(value: ChapterAction.showChapterDetailsAfterDelayIfNeeded)
                        .delay(for: .seconds(0.2), scheduler: env.mainQueue())
                        .eraseToEffect()
            }
            
        // this made for better animation of DisclosureGroup
        case .showChapterDetailsAfterDelayIfNeeded:
            if state.areAllChapterDetailsDownloaded {
                state.areChaptersShown = true
            }
            
            return .none
            
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
.binding()
