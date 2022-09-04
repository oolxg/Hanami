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
    let isOnline: Bool
    
    init(chapter: Chapter, isOnline: Bool = false) {
        self.chapter = chapter
        self.isOnline = isOnline
    }
    
    // we can have many 'chapterDetailsList' in one ChapterState because one chapter can be translated by different scanlation groups
    var chapterDetailsList: IdentifiedArrayOf<ChapterDetails> = []
    // '_chapterDetails' is only to accumulate all ChapterDetails and then show it at once
    // swiftlint:disable:next identifier_name
    var _chapterDetailsList: [ChapterDetails] = [] {
        didSet {
            // if all chapters fetched, this container is no longer needed
            // so we put all chapterDetails in 'chapterDetailsList' and clear this one
            if _chapterDetailsList.count == chaptersCount {
                chapterDetailsList = .init(uniqueElements: _chapterDetailsList.sorted {
                    $0.attributes.translatedLanguage < $1.attributes.translatedLanguage
                })
                _chapterDetailsList = []
            }
        }
    }
    var scanlationGroups: [UUID: ScanlationGroup] = [:]
    var cachedChaptersIDs = Set<UUID>()
    var chaptersCount: Int {
        chapter.others.count + 1
    }
    
    var id: UUID { chapter.id }
    
    @BindableState var areChaptersShown = false
    
    var confirmationDialog: ConfirmationDialogState<ChapterAction>?
    
    struct CancelChapterFetch: Hashable { let id: UUID }
}

enum ChapterAction: BindableAction, Equatable {
    case fetchChapterDetailsIfNeeded
    case userTappedOnChapterDetails(chapter: ChapterDetails)
    case chapterDetailsFetched(result: Result<Response<ChapterDetails>, AppError>)
    case scanlationGroupInfoFetched(result: Result<Response<ScanlationGroup>, AppError>, chapterID: UUID)
    case downloadChapterForOfflineReading(chapter: ChapterDetails)
    
    case deleteChapter(chapter: ChapterDetails)
    case chapterDeletionConfirmed(chapter: ChapterDetails)
    case cancelTapped

    case binding(BindingAction<ChapterState>)
}

struct ChapterEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
    let cacheClient: CacheClient
}

let chapterReducer = Reducer<ChapterState, ChapterAction, ChapterEnvironment> { state, action, env in
    switch action {
        case .fetchChapterDetailsIfNeeded:
            var effects: [Effect<ChapterAction, Never>] = []
            
            let allChapterIDs = [state.chapter.id] + state.chapter.others
            
            for chapterID in allChapterIDs {
                let possiblyCachedChapterDetails = env.databaseClient.fetchChapter(chapterID: chapterID)
                
                if state.chapterDetailsList[id: chapterID] == nil {
                    // if chapter is cached - no need to fetch it from API
                    if let cachedChapterDetails = possiblyCachedChapterDetails?.chapter {
                        state._chapterDetailsList.append(cachedChapterDetails)
                        state.cachedChaptersIDs.insert(cachedChapterDetails.id)
                        
                        if let scanlationGroup = cachedChapterDetails.scanlationGroup {
                            state.scanlationGroups[cachedChapterDetails.id] = scanlationGroup
                        } else if let scanlationGroupID = cachedChapterDetails.scanlationGroupID {
                            effects.append(
                                env.mangaClient.fetchScanlationGroup(scanlationGroupID)
                                    .receive(on: DispatchQueue.main)
                                    .catchToEffect {
                                        ChapterAction.scanlationGroupInfoFetched(
                                            result: $0,
                                            chapterID: cachedChapterDetails.id
                                        )
                                    }
                                    .cancellable(
                                        id: ChapterState.CancelChapterFetch(id: chapterID),
                                        cancelInFlight: true
                                    )
                            )
                        }
                    } else {
                        effects.append(
                            env.mangaClient.fetchChapterDetails(chapterID)
                                .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
                                .receive(on: DispatchQueue.main)
                                .catchToEffect(ChapterAction.chapterDetailsFetched)
                                .animation(.linear)
                                .cancellable(
                                    id: ChapterState.CancelChapterFetch(id: chapterID),
                                    cancelInFlight: true
                                )
                        )
                    }
                } else if possiblyCachedChapterDetails == nil {
                    state.cachedChaptersIDs.remove(chapterID)
                }
            }
            
            state.areChaptersShown.toggle()
            
            // all effects here are online, so is this store is using in offline mode
            // e.g. OfflineMangaStore->PagesStore->...->ChapterStore
            // we should fetch nothing 
            guard state.isOnline else { return .none }
            
            return effects.isEmpty ? .none : .merge(effects)
            
        case .deleteChapter(let chapter):
            state.confirmationDialog = ConfirmationDialogState(
                title: TextState("Delete this chapter from device?"),
                message: TextState("Delete this chapter from device?"),
                buttons: [
                    .destructive(TextState("Delete"), action: .send(.chapterDeletionConfirmed(chapter: chapter))),
                    .cancel(TextState("Cancel"), action: .send(.cancelTapped))
                ]
            )
            return .none
            
        case .chapterDeletionConfirmed(let chapter):
            state.cachedChaptersIDs.remove(chapter.id)
            state.confirmationDialog = nil
            
            var effects: [Effect<ChapterAction, Never>] = [
                env.databaseClient
                    .deleteChapter(chapterID: chapter.id)
                    .fireAndForget()
            ]
            
            if let pagesCount = env.databaseClient.fetchChapter(chapterID: chapter.id)?.pagesCount {
                effects.append(
                    env.mangaClient
                        .removeCachedPagesForChapter(chapter.id, pagesCount, env.cacheClient)
                        .fireAndForget()
                )
            }
            
            return .merge(effects)
            
        case .cancelTapped:
            state.confirmationDialog = nil
            return .none
            
        case .userTappedOnChapterDetails:
            return .none
            
        case .downloadChapterForOfflineReading(let chapter):
            state.cachedChaptersIDs.insert(chapter.id)
            return .none
            
        case .chapterDetailsFetched(let result):
            switch result {
                case .success(let response):
                    let chapter = response.data
                    
                    state._chapterDetailsList.append(chapter)
                    
                    if let scanlationGroup = response.data.scanlationGroup {
                        state.scanlationGroups[chapter.id] = scanlationGroup
                        return .none
                    }
                    
                    guard let scanlationGroupID = chapter.scanlationGroupID else {
                        return .none
                    }
                    
                    return env.mangaClient.fetchScanlationGroup(scanlationGroupID)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect {
                            ChapterAction.scanlationGroupInfoFetched(
                                result: $0,
                                chapterID: chapter.id
                            )
                        }
                        .cancellable(
                            id: ChapterState.CancelChapterFetch(id: response.data.id),
                            cancelInFlight: true
                        )
                    
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
