//
//  ChapterFeature.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage
import ModelKit
import Utils
import Logger

@Reducer
struct ChapterFeature {
    struct State: Equatable, Identifiable {
        // Chapter basic info
        let chapter: Chapter
        let online: Bool
        let parentManga: Manga
        
        init(chapter: Chapter, parentManga: Manga, online: Bool = false) {
            self.chapter = chapter
            self.online = online
            self.parentManga = parentManga
            downloader = ChapterLoaderFeature.State(parentManga: parentManga, online: online)
        }
        
        var downloader: ChapterLoaderFeature.State
        
        // we can have many 'chapterDetailsList' in one ChapterState because one chapter can be translated by different scanlation groups
        var chapterDetailsList: IdentifiedArrayOf<ChapterDetails> = []
        // '_chapterDetails' is only to accumulate all ChapterDetails and then show it at all once
        // swiftlint:disable:next identifier_name
        var _chapterDetailsList: [ChapterDetails] = [] {
            didSet {
                // if all chapters fetched, this container is no longer needed
                // so we put all chapterDetails in 'chapterDetailsList' and clear this one
                if _chapterDetailsList.count == chaptersCount {
                    chapterDetailsList = _chapterDetailsList.sorted { lhs, rhs in
                        // sort by lang and by ScanlationGroup's name
                        if lhs.attributes.translatedLanguage == rhs.attributes.translatedLanguage,
                           let lhsName = lhs.scanlationGroup?.name, let rhsName = rhs.scanlationGroup?.name {
                            return lhsName < rhsName
                        }
                        
                        if let lhsLang = lhs.attributes.translatedLanguage,
                           let rhsLang = rhs.attributes.translatedLanguage {
                            return lhsLang < rhsLang
                        }
                        
                        return false
                    }
                    .asIdentifiedArray
                    
                    _chapterDetailsList = []
                }
            }
        }
        var chaptersCount: Int {
            // need this for offline reading
            // when user deletes chapter, `chapter.others.count` doesn't change himself, only `chapterDetailsList.count`
            chapterDetailsList.isEmpty ? chapter.others.count + 1 : chapterDetailsList.count
        }
        
        var id: UUID { chapter.id }
        
        var areChaptersShown = false
        
        @PresentationState var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?
    }
    
    struct CancelChapterFetch: Hashable { let id: UUID }
    
    enum Action: Equatable {
        case onAppear
        case fetchChapterDetailsIfNeeded
        
        case userTappedOnChapterDetails(ChapterDetails)
        case chapterDeleteButtonTapped(chapterID: UUID)
        case downloadChapterButtonTapped(chapter: ChapterDetails)
        case cancelChapterDownloadButtonTapped(chapterID: UUID)
        case cancelTapped
        
        case chapterDetailsFetched(Result<Response<ChapterDetails>, AppError>)
        case downloaderAction(ChapterLoaderFeature.Action)
        
        case confirmationDialog(PresentationAction<ConfirmationDialog>)
        
        enum ConfirmationDialog: Equatable {
            case chapterDeletionConfirmed(chapterID: UUID)
        }
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { await $0(.downloaderAction(.retrieveCachedChaptersFromMemory)) }
                
            case .fetchChapterDetailsIfNeeded:
                var effects: [Effect<Action>] = []
                
                let allChapterIDs = [state.chapter.id] + state.chapter.others
                
                for chapterID in allChapterIDs {
                    let possiblyCachedChapterEntry = databaseClient.retrieveChapter(chapterID: chapterID)
                    
                    if state.chapterDetailsList[id: chapterID].isNil {
                        // if chapter is cached - no need to fetch it from API
                        if let cachedChapterDetails = possiblyCachedChapterEntry?.chapter {
                            if !state._chapterDetailsList.contains(where: { $0.id == chapterID }) {
                                state._chapterDetailsList.append(cachedChapterDetails)
                            }
                        } else if state.online {
                            // chapter is not cached, need to fetch
                            effects.append(
                                .run { send in
                                    try await Task.sleep(seconds: 0.3)
                                    let result = await mangaClient.fetchChapterDetails(for: chapterID)
                                    await send(.chapterDetailsFetched(result))
                                }
                                .cancellable(id: CancelChapterFetch(id: chapterID), cancelInFlight: true)
                            )
                        }
                    }
                }
                
                state.areChaptersShown.toggle()
                
                return .merge(effects)
                
            case .userTappedOnChapterDetails:
                return .none
                
            case .chapterDetailsFetched(let result):
                switch result {
                case .success(let response):
                    let chapter = response.data
                    
                    if !state._chapterDetailsList.contains(where: { $0.id == chapter.id }) {
                        state._chapterDetailsList.append(chapter)
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch chapterDetails: \(error)",
                        context: ["mangaID": "\(state.parentManga.id.uuidString.lowercased())"]
                    )
                    return .none
                }
                // MARK: - Caching
            case .chapterDeleteButtonTapped(let chapterID):
                state.confirmationDialog = ConfirmationDialogState(title: {
                    TextState("Delete this chapter from device?")
                }, actions: {
                    ButtonState(role: .destructive, action: .chapterDeletionConfirmed(chapterID: chapterID)) {
                        TextState("Delete")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                })
                
                return .none
                
            case .cancelTapped:
                state.confirmationDialog = nil
                return .none
                
            case .confirmationDialog(.presented(.chapterDeletionConfirmed(let chapterID))):
                if !state.online {
                    state.chapterDetailsList.remove(id: chapterID)
                }
                
                state.confirmationDialog = nil
                
                return .run { await $0(.downloaderAction(.chapterDeletionConfirmed(chapterID: chapterID))) }
                
            case .downloadChapterButtonTapped(let chapter):
                return .run { await $0(.downloaderAction(.downloadChapterButtonTapped(chapter: chapter))) }
                
            case .cancelChapterDownloadButtonTapped(let chapterID):
                state.confirmationDialog = ConfirmationDialogState(title: {
                    TextState("Stop chapter download?")
                }, actions: {
                    ButtonState(role: .destructive, action: .chapterDeletionConfirmed(chapterID: chapterID)) {
                        TextState("Stop download")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Continue download")
                    }
                })
                
                return .none
                // MARK: - Caching END
                
            case .downloaderAction:
                return .none
                
            case .confirmationDialog:
                return .none
            }
        }
        Scope(state: \.downloader, action: /Action.downloaderAction) {
            ChapterLoaderFeature()
        }
    }
}
