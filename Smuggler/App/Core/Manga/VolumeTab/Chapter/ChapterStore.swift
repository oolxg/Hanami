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
    // we can have many 'chapterDetails' in one ChapterState because one chapter can be translated by different scanlation groups
    // here are each chapter with details
    var chapterDetails: IdentifiedArrayOf<ChapterDetails> = []
    var scanlationGroups: [UUID: ScanlationGroup] = [:]
    var cachedChaptersIDs = Set<UUID>()
    
    var id: UUID { chapter.id }
    
    @BindableState var areChaptersShown = false {
        willSet {
            if newValue { shouldShowActivityIndicator = false }
        }
    }
    
    var loadingChapterDetailsCount = 0
    var shouldShowActivityIndicator = false
    var confiramtionDialog: ConfirmationDialogState<ChapterAction>?
}

enum ChapterAction: BindableAction, Equatable {
    case userTappedOnChapter
    case userTappedOnChapterDetails(chapter: ChapterDetails)
    case chapterDetailsDownloaded(result: Result<Response<ChapterDetails>, AppError>, chapterID: UUID)
    case scanlationGroupInfoFetched(result: Result<Response<ScanlationGroup>, AppError>, chapterID: UUID)
    case downloadChapterForOfflineReading(chapter: ChapterDetails)
    
    case userWantsToDeleteChapter(chapter: ChapterDetails)
    case userConfirmedChapterDelete(chapter: ChapterDetails)
    case cancelTapped

    case binding(BindingAction<ChapterState>)
}

struct ChapterEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
}

// About loading chapter pages

// we should load all pages when user opens chapter and only save it in caches directory
// when user open page, we immidiately get it from cache(or load it again if something happend

let chapterReducer = Reducer<ChapterState, ChapterAction, ChapterEnvironment> { state, action, env in
    switch action {
        case .userTappedOnChapter:
            var effects: [Effect<ChapterAction, Never>] = []
            
            if env.databaseClient.fetchChapter(chapterID: state.chapter.id) != nil {
                state.cachedChaptersIDs.insert(state.chapter.id)
            } else {
                state.cachedChaptersIDs.remove(state.chapter.id)
            }
            
            for chapterID in state.chapter.others {
                if env.databaseClient.fetchChapter(chapterID: chapterID) != nil {
                    state.cachedChaptersIDs.insert(chapterID)
                } else {
                    state.cachedChaptersIDs.remove(chapterID)
                }
            }

            // if we fetched info about chapters, it means that pages info is downloaded too
            // (or externalURL, manga if to read on other webiste)
            if state.chapterDetails[id: state.chapter.id] == nil {
                // need this var because state is 'inout'
                let chapterID = state.chapter.id
                effects.append(
                    env.mangaClient.fetchChapterDetails(chapterID)
                        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { ChapterAction.chapterDetailsDownloaded(result: $0, chapterID: chapterID) }
                        .animation(.linear)
                )
            }
            
            for (i, chapterID) in state.chapter.others.enumerated() where state.chapterDetails[id: chapterID] == nil {
                effects.append(
                    env.mangaClient.fetchChapterDetails(chapterID)
                        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { ChapterAction.chapterDetailsDownloaded(
                            result: $0,
                            chapterID: chapterID
                        ) }
                        .animation(.linear)
                )
            }
            
            state.loadingChapterDetailsCount = effects.count
            
            if effects.isEmpty {
                state.areChaptersShown.toggle()
            } else {
                state.shouldShowActivityIndicator = true
            }

            return effects.isEmpty ? .none : .merge(effects)
            
        case .userWantsToDeleteChapter(let chapter):
            state.confiramtionDialog = ConfirmationDialogState(
                title: TextState("Delete this chapter from device?"),
                message: TextState("Delete this chapter from device?"),
                buttons: [
                    .destructive(TextState("Delete"), action: .send(.userConfirmedChapterDelete(chapter: chapter))),
                    .cancel(TextState("Cancel"), action: .send(.cancelTapped))
                ]
            )
            return .none
            
        case .userConfirmedChapterDelete(let chapter):
            state.cachedChaptersIDs.remove(chapter.id)
            state.confiramtionDialog = nil
            return .none
            
        case .cancelTapped:
            state.confiramtionDialog = nil
            return .none
            
        case .userTappedOnChapterDetails:
            // this case is only for getting it in MangaFeature
            return .none
            
        case .downloadChapterForOfflineReading(let chapter):
            state.cachedChaptersIDs.insert(chapter.id)
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
                    
                    state.areChaptersShown = state.loadingChapterDetailsCount == 0
                    
                    if let cachedChapter = env.databaseClient.fetchChapter(chapterID: chapterID) {
                        state.cachedChaptersIDs.insert(cachedChapter.id)
                    }
                    
                    if state.loadingChapterDetailsCount == 0 {
                        state.chapterDetails.sort {
                            $0.attributes.translatedLanguage > $1.attributes.translatedLanguage
                        }
                    }
                    
                    return env.mangaClient.fetchScanlationGroup(scanlationGroupID)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect {
                            ChapterAction.scanlationGroupInfoFetched(
                                result: $0,
                                chapterID: response.data.id
                            )
                        }
                    
                case .failure(let error):
                    print("error on downloading chapter details, \(error)")

                    state.areChaptersShown = state.loadingChapterDetailsCount == 0
                    if state.loadingChapterDetailsCount == 0 {
                        state.chapterDetails.sort {
                            $0.attributes.translatedLanguage > $1.attributes.translatedLanguage
                        }
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
        case .binding(\.$areChaptersShown):
                // sometimes DisclosureGroup can toggle `areChaptersShown`,
                // so if we getting signal as binding from view, we set `areChaptersShown` back
            state.areChaptersShown.toggle()
            return .none
            
        case .binding:
            return .none
    }
}
.binding()
