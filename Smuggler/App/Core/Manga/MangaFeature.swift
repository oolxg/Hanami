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
        // Manga ID - Volumes
    var volumes: IdentifiedArrayOf<Volume> = []
}

enum MangaViewAction: Equatable {
    case onAppear
    case onDisappear
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
        struct CancelPagesLoading: Hashable { }
        
        switch action {
            case .onAppear:
                if !state.volumes.isEmpty {
                    return .none
                }
                
                return env.downloadMangaVolumes(state.manga.id, env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(MangaViewAction.volumesDownloaded)
            case .onDisappear:
                return .cancel(id: CancelPagesLoading())
            case .volumesDownloaded(let result):
                switch result {
                    case .success(let response):
                        // all chapter IDs are loaded, we can send request to @Home to get hashes
                        state.volumes = .init(uniqueElements: response.volumes)
                        for volume in state.volumes {
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
