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
    
    struct CancelChapterFetch: Hashable { }
}

enum ChapterAction: BindableAction, Equatable {
    case userTappedOnChapter
    case userTappedOnChapterDetails(chapter: ChapterDetails)
    case chapterDetailsDownloaded(result: Result<Response<ChapterDetails>, AppError>)
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

            if state.chapterDetails[id: state.chapter.id] == nil {
                effects.append(
                    env.mangaClient.fetchChapterDetails(state.chapter.id)
                        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(ChapterAction.chapterDetailsDownloaded)
                        .animation(.linear)
                        .cancellable(id: ChapterState.CancelChapterFetch())
                )
            }
            
            for otherChapterID in state.chapter.others where state.chapterDetails[id: otherChapterID] == nil {
                effects.append(
                    env.mangaClient.fetchChapterDetails(otherChapterID)
                        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(ChapterAction.chapterDetailsDownloaded)
                        .animation(.linear)
                        .cancellable(id: ChapterState.CancelChapterFetch())
                )
            }
            
            print(effects.count)
            
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
            return .none
            
        case .downloadChapterForOfflineReading(let chapter):
            state.cachedChaptersIDs.insert(chapter.id)
            return .none
            
        case .chapterDetailsDownloaded(let result):
            state.loadingChapterDetailsCount -= 1
            switch result {
                case .success(let response):
                    state.chapterDetails.append(response.data)
                    
                    guard let scanlationGroupID = response.data.scanltaionGroupID else {
                        return .none
                    }
                    
                    
                    if state.loadingChapterDetailsCount == 0 {
                        state.chapterDetails.sort {
                            $0.attributes.translatedLanguage > $1.attributes.translatedLanguage
                        }
                    }
                    
                    state.areChaptersShown = state.loadingChapterDetailsCount == 0
                    
                    return env.mangaClient.fetchScanlationGroup(scanlationGroupID)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect {
                            ChapterAction.scanlationGroupInfoFetched(
                                result: $0,
                                chapterID: response.data.id
                            )
                        }
                        .cancellable(id: ChapterState.CancelChapterFetch())
                    
                case .failure(let error):
                    print("error on downloading chapter details, \(error)")

                    if state.loadingChapterDetailsCount == 0 {
                        state.chapterDetails.sort {
                            $0.attributes.translatedLanguage > $1.attributes.translatedLanguage
                        }
                    }
                    
                    state.areChaptersShown = state.loadingChapterDetailsCount == 0
                    
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
            
        case .binding:
            return .none
    }
}
.binding()
