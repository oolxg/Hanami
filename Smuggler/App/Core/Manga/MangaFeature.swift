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

enum MangaViewAction {
    case onAppear
    case volumesDownloaded(Result<Volumes, APIError>)
    // UUID - for chapter ID, Int - chapter index in manga
    case volumeTabAction(UUID, VolumeTabAction)
}

struct MangaViewEnvironment {
    var downloadMangaVolumes: (_ mangaID: UUID, _ decoder: JSONDecoder) -> Effect<Volumes, APIError>
}

let mangaViewReducer: Reducer<MangaViewState, MangaViewAction, SystemEnvironment<MangaViewEnvironment>> = .combine(
    // swiftlint:disable:next trailing_closure
    volumeTabReducer.forEach(
        state: \.volumeTabStates,
        action: /MangaViewAction.volumeTabAction,
        environment: { _ in .live(
                environment: .init(
            ),
            isMainQueueWithAnimation: true
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                if !state.volumeTabStates.isEmpty {
                    return .cancel(id: CancelClearCacheForManga(mangaID: state.manga.id))
                }
                
                return env.downloadMangaVolumes(state.manga.id, env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(MangaViewAction.volumesDownloaded)

            case .volumesDownloaded(let result):
                switch result {
                    case .success(let response):
                        state.volumeTabStates = .init(
                            uniqueElements: response.volumes.map { VolumeTabState(volume: $0) }
                        )
                        return .none
                        
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error)")
                        return .none
                }
                
            case .volumeTabAction:
                return .none
        }
    }
)
