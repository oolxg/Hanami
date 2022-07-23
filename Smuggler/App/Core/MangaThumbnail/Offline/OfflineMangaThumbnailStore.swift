//
//  OfflineMangaThumbnailStore.swift
//  Smuggler
//
//  Created by mk.pwnz on 23/07/2022.
//

import Foundation
import ComposableArchitecture

struct OfflineMangaThumbnailState: Equatable, Identifiable {
    let manga: Manga
    
    init(manga: Manga) {
        self.manga = manga
        mangaViewState = OfflineMangaViewState(manga: manga)
    }
    
    var mangaViewState: OfflineMangaViewState
    
    var id: UUID { manga.id }
}

enum OfflineMangaThumbnailAction {
    case onAppear
    case userOpenedMangaView
    case userLeftMangaView
    case userLeftMangaViewDelayCompleted
    case mangaAction(OfflineMangaViewAction)
}

let offlineMangaThumbnailReducer = Reducer<OfflineMangaThumbnailState, OfflineMangaThumbnailAction, MangaThumbnailEnvironment>.combine(
    offlineMangaViewReducer.pullback(
        state: \.mangaViewState,
        action: /OfflineMangaThumbnailAction.mangaAction,
        environment: { .init(
            databaseClient: $0.databaseClient,
            mangaClient: $0.mangaClient
        ) }
    ),
    Reducer { state, action, env in
        return .none
    }
)

