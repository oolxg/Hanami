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
    init(chapter: Chapter) {
        self.chapter = chapter
    }
    // Chapter basic info
    let chapter: Chapter
    // we can have many 'chapterDetals' in one ChapterState because one chapter can be translated by different scanlation groups
    // here are each chapter with details
    var chapterDetails: [UUID: ChapterDetails] = [:]
    // Chapter UUID - Info about chapter pages
    var pagesInfo: [UUID: ChapterPagesInfo] = [:]
    // Chapter UUID - Chapter pages
    var pages: [UUID: [UIImage]] = [:]
    
    var id: UUID {
        chapter.id
    }
}

enum ChapterAction {
    case listIsExpanded
    // UUID - chapter ID
    case mangaPageInfoDownloaded(result: Result<ChapterPagesInfo, APIError>, chapterID: UUID)
    // UUID - chapter ID
    case chapterDetailsDownloaded(result: Result<Response<ChapterDetails>, APIError>, chapterID: UUID)
}

struct ChapterEnvironment {
    var downloadPagesInfo: (UUID) -> Effect<ChapterPagesInfo, APIError>
    var downloadChapterInfo: (UUID, JSONDecoder) -> Effect<Response<ChapterDetails>, APIError>
}

let chapterReducer = Reducer<ChapterState, ChapterAction, SystemEnvironment<ChapterEnvironment>> { state, action, env in
    switch action {
        case .listIsExpanded:
            guard state.pagesInfo[state.chapter.id] == nil else {
                return .none
            }
            
            var effects: [Effect<ChapterAction, Never>] = []
            
            // need this var because state is 'inout'
            let chapterID = state.chapter.id
            effects.append(contentsOf: [
                env.downloadPagesInfo(state.chapter.id)
                    .receive(on: env.mainQueue())
                    .catchToEffect { ChapterAction.mangaPageInfoDownloaded(result: $0, chapterID: chapterID) },
                
                env.downloadChapterInfo(chapterID, env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect { ChapterAction.chapterDetailsDownloaded(result: $0, chapterID: chapterID) }
            ])
            
            
            for otherChapterID in state.chapter.others {
                effects.append(contentsOf: [
                    env.downloadPagesInfo(otherChapterID)
                        .receive(on: env.mainQueue())
                        .catchToEffect { ChapterAction.mangaPageInfoDownloaded(result: $0, chapterID: otherChapterID) },
                    
                    env.downloadChapterInfo(otherChapterID, env.decoder())
                        .receive(on: env.mainQueue())
                        .catchToEffect { ChapterAction.chapterDetailsDownloaded(result: $0, chapterID: otherChapterID) }
                ])
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
        case .chapterDetailsDownloaded(result: let result, chapterID: let chapterID):
            switch result {
                case .success(let response):
                    state.chapterDetails[chapterID] = response.data
                    return .none
                case .failure(let error):
                    print("error on downloading chapter details, \(error)")
                    return .none
            }
    }
}

