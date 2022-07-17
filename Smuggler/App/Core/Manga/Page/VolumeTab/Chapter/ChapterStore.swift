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
    var chapterDetails: IdentifiedArrayOf<ChapterDetails> = []
    // '_chapterDetails' is only to accumulate all ChapterDetails and then show it at once
    // swiftlint:disable:next identifier_name
    var _chapterDetails: [ChapterDetails] = []
    var scanlationGroups: [UUID: ScanlationGroup] = [:]
    var cachedChaptersIDs = Set<UUID>()
    
    var id: UUID { chapter.id }
    
    @BindableState var areChaptersShown = false
    
    var confiramtionDialog: ConfirmationDialogState<ChapterAction>?
    
    struct CancelChapterFetch: Hashable { }
}

enum ChapterAction: BindableAction, Equatable {
    case fetchChapterDetailsIfNeeded
    case userTappedOnChapterDetails(chapter: ChapterDetails)
    case chapterDetailsFetched(result: Result<Response<ChapterDetails>, AppError>)
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
        case .fetchChapterDetailsIfNeeded:
            var effects: [Effect<ChapterAction, Never>] = []
            
            if state.chapterDetails[id: state.chapter.id] == nil {
                if env.databaseClient.fetchChapter(chapterID: state.chapter.id) != nil {
                    state.cachedChaptersIDs.insert(state.chapter.id)
                } else {
                    state.cachedChaptersIDs.remove(state.chapter.id)
                }
                
                effects.append(
                    env.mangaClient.fetchChapterDetails(state.chapter.id)
                        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(ChapterAction.chapterDetailsFetched)
                        .animation(.linear)
                        .cancellable(id: ChapterState.CancelChapterFetch())
                )
            }
            
            for otherChapterID in state.chapter.others where state.chapterDetails[id: otherChapterID] == nil {
                if env.databaseClient.fetchChapter(chapterID: otherChapterID) != nil {
                    state.cachedChaptersIDs.insert(otherChapterID)
                } else {
                    state.cachedChaptersIDs.remove(otherChapterID)
                }
                
                effects.append(
                    env.mangaClient.fetchChapterDetails(otherChapterID)
                        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(ChapterAction.chapterDetailsFetched)
                        .animation(.linear)
                        .cancellable(id: ChapterState.CancelChapterFetch())
                )
            }
            
            state.areChaptersShown.toggle()

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
            
        case .chapterDetailsFetched(let result):
            switch result {
                case .success(let response):
                    state._chapterDetails.append(response.data)
                    
                    if state._chapterDetails.count == state.chapter.others.count + 1 {
                        state.chapterDetails = .init(uniqueElements: state._chapterDetails.sorted {
                            $0.attributes.translatedLanguage < $1.attributes.translatedLanguage
                        })
                        state._chapterDetails = []
                    }
                    
                    guard let scanlationGroupID = response.data.scanltaionGroupID else {
                        return .none
                    }
                    
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
