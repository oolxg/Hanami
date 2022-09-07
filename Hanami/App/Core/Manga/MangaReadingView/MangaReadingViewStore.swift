//
//  MangaReadingViewFeature.swift
//  Hanami
//
//  Created by Oleg on 16/06/2022.
//

import Foundation
import ComposableArchitecture

enum MangaReadingViewState: Equatable {
    case online(OnlineMangaReadingViewState)
    case offline(OfflineMangaReadingViewState)
    
    var chapterIndex: Double? {
        switch self {
            case .online(let onlineMangaReadingViewState):
                return onlineMangaReadingViewState.chapterIndex
                
            case .offline(let offlineMangaReadingViewState):
                return offlineMangaReadingViewState.chapter.attributes.chapterIndex
        }
    }
}


enum MangaReadingViewAction {
    case online(OnlineMangaReadingViewAction)
    case offline(OfflineMangaReadingViewAction)
}
       

struct MangaReadingViewEnvironment {
    let databaseClient: DatabaseClient
    let cacheClient: CacheClient
    let imageClient: ImageClient
    let mangaClient: MangaClient
    let hudClient: HUDClient
}
