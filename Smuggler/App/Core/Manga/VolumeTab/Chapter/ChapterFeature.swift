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
    
    @BindableState var areChaptersShown = false {
        willSet {
            if newValue {
                shouldShowActivityIndicator = false
            }
        }
    }
    
    var loadingChapterDetailsCount = 0
    var shouldShowActivityIndicator = false
}

enum ChapterAction: BindableAction {
    case userTappedOnChapter
    case userTappedOnChapterDetails(chapter: ChapterDetails)
    case chapterDetailsDownloaded(result: Result<Response<ChapterDetails>, AppError>, chapterID: UUID)
    case scanlationGroupInfoFetched(result: Result<Response<ScanlationGroup>, AppError>, chapterID: UUID)
    
    case binding(BindingAction<ChapterState>)
}

struct ChapterEnvironment {
    var downloadChapterInfo: (UUID) -> Effect<Response<ChapterDetails>, AppError>
    var fetchScanlationGroupInfo: (UUID) -> Effect<Response<ScanlationGroup>, AppError>
}

// About loading chapter pages

// we should load all pages when user opens chapter and only save it in caches directory
// when user open page, we immidiately get it from cache(or load it again if something happend

let chapterReducer = Reducer<ChapterState, ChapterAction, ChapterEnvironment> { state, action, env in
    switch action {
        case .userTappedOnChapter:
            var effects: [Effect<ChapterAction, Never>] = []

            // if we fetched info about chapters, it means that pages info is downloaded too
            // (or externalURL, manga if to read on other webiste)
            if state.chapterDetails[id: state.chapter.id] == nil {
                // need this var because state is 'inout'
                let chapterID = state.chapter.id
                effects.append(
                    env.downloadChapterInfo(chapterID)
                        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { ChapterAction.chapterDetailsDownloaded(result: $0, chapterID: chapterID) }
                        .animation(.linear)
                )
            }
            
            for (i, otherChapterID) in state.chapter.others.enumerated() {
                if state.chapterDetails[id: otherChapterID] == nil {
                    effects.append(
                        env.downloadChapterInfo(otherChapterID)
                            .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect { ChapterAction.chapterDetailsDownloaded(
                                result: $0,
                                chapterID: otherChapterID
                            ) }
                            .animation(.linear)
                    )
                }
            }
            
            state.loadingChapterDetailsCount = effects.count
            
            if effects.isEmpty {
                state.areChaptersShown.toggle()
            } else {
                state.shouldShowActivityIndicator = true
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
                    
                    if state.loadingChapterDetailsCount == 0 {
                        state.chapterDetails.sort { $0.languageFlag > $1.languageFlag }
                        state.areChaptersShown = true
                    }
                    
                    return env.fetchScanlationGroupInfo(scanlationGroupID)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect {
                            ChapterAction.scanlationGroupInfoFetched(
                                result: $0,
                                chapterID: response.data.id
                            )
                        }
                    
                case .failure(let error):
                    print("error on downloading chapter details, \(error)")
                    
                    if state.loadingChapterDetailsCount == 0 {
                        state.chapterDetails.sort { $0.languageFlag > $1.languageFlag }
                        state.areChaptersShown = true
                    }
                    
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
.binding()
