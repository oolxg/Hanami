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
    
    var currentReadingChapter: ChapterDetails?
    
    @BindableState var isUserOnReadingView = false
    var mangaRedingViewState: MangaReadingViewState? {
        willSet {
            if newValue == nil {
                isUserOnReadingView = false
            }
        }
    }
    
    var selectedTab: SelectedTab = .chapters
    
    enum SelectedTab: String, Equatable {
        case about = "About"
        case chapters = "Chapters"
    }

    // should on be used for clearing cache
    mutating func reset() {
        mangaCover = nil
        statistics = nil
        volumeTabStates = []
        isVolumesLoaded = false
        currentReadingChapter = nil
        isUserOnReadingView = false
    }
}

enum MangaViewAction: BindableAction {
    case onAppear
    case volumesDownloaded(Result<Volumes, APIError>)
    case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, APIError>)
    case mangaTabChanged(MangaViewState.SelectedTab)
    case volumeTabAction(volumeID: UUID, volumeAction: VolumeTabAction)
    
    case mangaReadingViewAction(MangaReadingViewAction)
    case binding(BindingAction<MangaViewState>)
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
    // swiftlint:disable:next trailing_closure
    mangaReadingViewReducer.optional()
        .pullback(
            state: \.mangaRedingViewState,
            action: /MangaViewAction.mangaReadingViewAction,
            environment: { _ in .live(
                environment: .init(
                    fetchChapterPagesInfo: fetchPageInfoForChapter),
                isMainQueueAnimated: true
            ) }
        ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                var effects: [Effect<MangaViewAction, Never>] = []
                
                if state.statistics == nil {
                    effects.append(
                        env.fetchMangaStatistics(state.manga.id)
                            .receive(on: env.mainQueue())
                            .catchToEffect(MangaViewAction.mangaStatisticsDownloaded)
                    )
                }
                
                if state.volumeTabStates.isEmpty {
                    effects.append(
                        env.downloadMangaVolumes(state.manga.id, env.decoder())
                            .receive(on: env.mainQueue())
                            .catchToEffect(MangaViewAction.volumesDownloaded)
                    )
                }
                        
                return .merge(effects)

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
                
            case .volumeTabAction(_, let volumeTabAction):
                // we're looking for action on chapters
                // when user taps on some chapter, we send him to reading view
                switch volumeTabAction {
                    case .chapterAction(_, let chapterAction):
                        switch chapterAction {
                            case .onTapGesture(let chapterID):
                                state.mangaRedingViewState = MangaReadingViewState(chapterID: chapterID)
                                state.isUserOnReadingView = true
                            default:
                                break
                        }
                }
                return .none
                
            case .mangaReadingViewAction:
                return .none
                
            case .binding:
                return .none
        }
    }
)
