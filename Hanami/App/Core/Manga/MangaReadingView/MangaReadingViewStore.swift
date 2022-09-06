//
//  MangaReadingViewFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import Foundation
import ComposableArchitecture
import Kingfisher
import class SwiftUI.UIImage

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
    
    var chapterID: UUID {
        switch self {
            case .online(let onlineMangaReadingViewState):
                return onlineMangaReadingViewState.chapterID
                
            case .offline(let offlineMangaReadingViewState):
                return offlineMangaReadingViewState.chapter.id
        }
    }
}


enum MangaReadingViewAction {
    case online(OnlineMangaReadingViewAction)
    case offline(OfflineMangaReadingViewAction)
}
       
