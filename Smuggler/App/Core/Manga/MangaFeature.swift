//
//  MangaFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

    // TODO: - Rewrite logic to make images load not for all available chapters
    // Should extract Chapter as a separate component and load chapter info onTap/onSomeAction, after the chapter if opened, should load pages

struct MangaViewState: Equatable {
    let manga: Manga
    
    var volumeTabStates: IdentifiedArrayOf<VolumeTabState> = []
}

enum MangaViewAction: Equatable {
    case onAppear
    case onDisappear
    case onDisappearDelayCompleted
    case volumesDownloaded(Result<Volumes, APIError>)
    // UUID - for chapter ID, Int - chapter index in manga
    case volumeTabAction(UUID, VolumeTabAction)
}

struct MangaViewEnvironment {
        // Arguments for downloadChapters - (mangaID: UUID, decoder: JSONDecoder)
    var downloadMangaVolumes: (UUID, JSONDecoder) -> Effect<Volumes, APIError>
}


let mangaViewReducer: Reducer<MangaViewState, MangaViewAction, SystemEnvironment<MangaViewEnvironment>> = .combine(
    volumeTabReducer.forEach(
        state: \.volumeTabStates,
        action: /MangaViewAction.volumeTabAction,
        environment:  { _ in .live(
            environment: .init(
            ),
            isMainQueueWithAnimation: true
        ) }
    ),
    Reducer { state, action, env in
        // this struct is to delete cached info about manga
        struct CancelClearCache: Hashable { let mangaID: UUID }
        
        switch action {
            case .onAppear:
                if !state.volumeTabStates.isEmpty {
                    return .cancel(id: CancelClearCache(mangaID: state.manga.id))
                }
                
                return env.downloadMangaVolumes(state.manga.id, env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(MangaViewAction.volumesDownloaded)
            case .onDisappear:
                // Runs a delay(60 sec.) when user leave MangaView, after that all downloaded data will be deleted to save RAM
                // Can be cancelled if user returns wihing 60 sec.
                return Effect(value: MangaViewAction.onDisappearDelayCompleted)
                    .delay(for: .seconds(60), scheduler: env.mainQueue())
                    .eraseToEffect()
                    .cancellable(id: CancelClearCache(mangaID: state.manga.id))
            case .onDisappearDelayCompleted:
                state.volumeTabStates = []
                return .none
            case .volumesDownloaded(let result):
                switch result {
                    case .success(let response):
                        for volume in response.volumes {
                            state.volumeTabStates = .init(uniqueElements: response.volumes.map( { VolumeTabState(volume: $0) }))
                        }
                        
                        return .none
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error)")
                        return .none
                }
            case .volumeTabAction(_, _):
                return .none
        }
    }
)
