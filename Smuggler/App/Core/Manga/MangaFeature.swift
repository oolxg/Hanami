//
//  MangaFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct MangaViewState: Equatable {
    let manga: Manga
    var mangaCover: UIImage?
    var statistics: MangaStatistics?
    
    var volumeTabStates: IdentifiedArrayOf<VolumeTabState> = []
    var isVolumesLoaded = false
    var shouldShowEmptyMangaMessage: Bool {
        isVolumesLoaded && volumeTabStates.isEmpty
    }
    
    var selectedTab: SelectedTab = .chapters
    
    enum SelectedTab: String, Equatable {
        case about = "About"
        case chapters = "Chapters"
    }
}

enum MangaViewAction {
    case onAppear
    case volumesDownloaded(Result<Volumes, APIError>)
    case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, APIError>)
    case mangaTabChanged(MangaViewState.SelectedTab)
    case volumeTabAction(chapterID: UUID, volumeAction: VolumeTabAction)
}

struct MangaViewEnvironment {
    var downloadMangaVolumes: (_ mangaID: UUID, _ decoder: JSONDecoder) -> Effect<Volumes, APIError>
    var fetchMangaStatistics: (_ mangaID: UUID) -> Effect<MangaStatisticsContainer, APIError>
}

let mangaViewReducer: Reducer<MangaViewState, MangaViewAction, SystemEnvironment<MangaViewEnvironment>> = .combine(
    // swiftlint:disable:next trailing_closure
    volumeTabReducer.forEach(
        state: \.volumeTabStates,
        action: /MangaViewAction.volumeTabAction,
        environment: { _ in .live(
                environment: .init(
            ),
            isMainQueueAnimated: true
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                if !state.volumeTabStates.isEmpty {
                    return .cancel(id: CancelClearCacheForManga(mangaID: state.manga.id))
                }
                
                
                return .merge(
                    env.fetchMangaStatistics(state.manga.id)
                        .receive(on: env.mainQueue())
                        .catchToEffect(MangaViewAction.mangaStatisticsDownloaded),
                    
                    env.downloadMangaVolumes(state.manga.id, env.decoder())
                        .receive(on: env.mainQueue())
                        .catchToEffect(MangaViewAction.volumesDownloaded)
                )

            case .volumesDownloaded(let result):
                switch result {
                    case .success(let response):
                        state.isVolumesLoaded = true
                        state.volumeTabStates = .init(
                            uniqueElements: response.volumes.map { VolumeTabState(volume: $0) }
                        )
                        return .none
                        
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error)")
                        return .none
                }
                
            case .mangaStatisticsDownloaded(let result):
                switch result {
                    case .success(let response):
                        state.statistics = response.statistics[state.manga.id]
                        return .none
                        
                    case .failure(let error):
                        print("error on mangaFetchStatistics, \(error)")
                        return .none
                }
                
            case .mangaTabChanged(let newTab):
                state.selectedTab = newTab
                return .none
                
            case .volumeTabAction:
                return .none
        }
    }
)
