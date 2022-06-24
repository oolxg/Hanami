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
    var statistics: MangaStatistics?

    var coverArt: UIImage?
    var volumeTabStates: IdentifiedArrayOf<VolumeTabState> = []
    var areVolumesLoaded = false
    var shouldShowEmptyMangaMessage: Bool {
        areVolumesLoaded && volumeTabStates.isEmpty
    }
    
    var selectedTab: SelectedTab = .chapters
    enum SelectedTab: String, Equatable {
        case about = "About"
        case chapters = "Chapters"
    }
    
    // MARK: - Props for reading view
    @BindableState var isUserOnReadingView = false
    // if user reads some chapter with scanlation group 'A', e.g. ch. 21
    // it means we have to get ch. 22(as next chapter) and 20(as previous) from the scanlation group 'A'
    // this indexes are array indexes in 'sameScanlationGroupChapters'
    var nextReadingChapterIndex: Int?
    var previousReadingChapterIndex: Int?
    
    var mangaReadingViewState: MangaReadingViewState? {
        willSet {
            if newValue != nil {
                isUserOnReadingView = true
            } else {
                isUserOnReadingView = false
                nextReadingChapterIndex = nil
                previousReadingChapterIndex = nil
                sameScanlationGroupChapters = nil
            }
        }
    }
    // if user starts reading some chapter, we fetch all chapters from the same scanlation group
    var sameScanlationGroupChapters: [Chapter]?
    
    // should on be used for clearing cache
    mutating func reset() {
        volumeTabStates = []
        areVolumesLoaded = false
        isUserOnReadingView = false
        nextReadingChapterIndex = nil
        previousReadingChapterIndex = nil
        sameScanlationGroupChapters = nil
    }
}

enum MangaViewAction: BindableAction {
    // MARK: - Actions to be called from view
    case onAppear
    case mangaTabChanged(MangaViewState.SelectedTab)
    case userLeftMangaReadingView

    // MARK: - Actions to be called from reducer
    case computeNextAndPreviousChapterIndexes
    case userWantsToReadChapter(chapter: ChapterDetails)
    case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, APIError>)
    case volumesDownloaded(Result<Volumes, APIError>)
    case sameScanlationGroupChaptersFetched(Result<Volumes, APIError>)
    
    // MARK: - Substate actions
    case volumeTabAction(volumeID: UUID, volumeAction: VolumeTabAction)
    case mangaReadingViewAction(MangaReadingViewAction)
    
    // MARK: - Binding
    case binding(BindingAction<MangaViewState>)
}

struct MangaViewEnvironment {
    var fetchMangaVolumes: (
        _ mangaID: UUID,
        _ scanlationGroup: UUID?,
        _ translatedLanguage: String?,
        _ decoder: JSONDecoder
    ) -> Effect<Volumes, APIError>
    
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
    mangaReadingViewReducer.optional().pullback(
        state: \.mangaReadingViewState,
        action: /MangaViewAction.mangaReadingViewAction,
        environment: { _ in .live(
            environment: .init(
                fetchChapterPagesInfo: fetchPageInfoForChapter
            ),
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
                        // we are loading here all chapters, no need to select lang or scanlation group
                        env.fetchMangaVolumes(state.manga.id, nil, nil, env.decoder())
                            .receive(on: env.mainQueue())
                            .catchToEffect(MangaViewAction.volumesDownloaded)
                    )
                }
                        
                return .merge(effects)

            case .volumesDownloaded(let result):
                switch result {
                    case .success(let response):
                        state.areVolumesLoaded = true
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
               
            // user tapped on chapter, therefore we're sending him to reading view
            case .userWantsToReadChapter(let chapter):
                state.mangaReadingViewState = MangaReadingViewState(
                    chapterID: chapter.id,
                    chapterIndex: chapter.attributes.chapterIndex
                )
                
                UITabBar.hideTabBar(animated: false)
                
                return env.fetchMangaVolumes(
                    state.manga.id,
                    chapter.scanltaionGroupID,
                    chapter.attributes.translatedLanguage,
                    env.decoder()
                )
                .receive(on: env.mainQueue())
                .catchToEffect(MangaViewAction.sameScanlationGroupChaptersFetched)
                
            // here we're fetching all chapters from the same scanlation group, that translated current reading chapter
            case .sameScanlationGroupChaptersFetched(let result):
                switch result {
                    case .success(let response):
                        state.sameScanlationGroupChapters = response.volumes.flatMap(\.chapters).sorted(by: <)
                                            
                        return Effect(value: MangaViewAction.computeNextAndPreviousChapterIndexes)
                        
                    case .failure(let error):
                        print("error on chaptersDownloaded, \(error)")
                        return .none
                }
                
            case .computeNextAndPreviousChapterIndexes:
                // it's index from mangaDex API, not index in 'sameScanlationGroupChapters'
                let currentReadingChapterIndex = state.mangaReadingViewState?.chapterIndex

                // here we're trying to get index in 'sameScanlationGroupChapters'
                guard let chapterIndex = state.sameScanlationGroupChapters?
                    .firstIndex(where: { $0.chapterIndex == currentReadingChapterIndex }) else {
                    return .none
                }
                
                if chapterIndex > 0 {
                    state.previousReadingChapterIndex = chapterIndex - 1
                } else {
                    state.previousReadingChapterIndex = nil
                }
                
                if chapterIndex < state.sameScanlationGroupChapters!.count - 1 {
                    state.nextReadingChapterIndex = chapterIndex + 1
                } else {
                    state.nextReadingChapterIndex = nil
                }
                
                return .none
                
            case .userLeftMangaReadingView:
                UITabBar.showTabBar(animated: true)
                state.mangaReadingViewState = nil
                return .none
                
            case .volumeTabAction(_, let volumeTabAction):
                // we're looking for action on chapters
                // when user taps on some chapter, we send him to reading view
                switch volumeTabAction {
                    case .chapterAction(_, let chapterAction):
                        switch chapterAction {
                            case .onTapGesture(let chapter):
                                return Effect(
                                    value: MangaViewAction.userWantsToReadChapter(chapter: chapter)
                                )
                                
                            default:
                                return .none
                        }
                }
                
            case .mangaReadingViewAction(let mangaReadingViewAction):
                switch mangaReadingViewAction {
                    case .userTappedOnNextChapterButton:
                        guard let nextChapterIndex = state.nextReadingChapterIndex,
                              let nextChapter = state.sameScanlationGroupChapters?[nextChapterIndex] else {
                            return .none
                        }
                        
                        state.mangaReadingViewState = MangaReadingViewState(
                            chapterID: nextChapter.id,
                            chapterIndex: nextChapter.chapterIndex
                        )
                        
                        // we're firing this effect -> Effect(value: MangaViewAction.mangaReadingViewAction(.userStartedReadingChapter))
                        // to download new pages. View itself doesn't disappear -> it doesn't appear, so we have to do it manually
                        return .merge(
                            Effect(value: MangaViewAction.computeNextAndPreviousChapterIndexes),
                            Effect(value: MangaViewAction.mangaReadingViewAction(.userStartedReadingChapter))
                        )
                        
                    case .userTappedOnPreviousChapterButton:
                        guard let previousChapterIndex = state.previousReadingChapterIndex,
                              let previousChapter = state.sameScanlationGroupChapters?[previousChapterIndex] else {
                            return .none
                        }
                        
                        state.mangaReadingViewState = MangaReadingViewState(
                            chapterID: previousChapter.id,
                            chapterIndex: previousChapter.chapterIndex
                        )
                        
                        // we're firing this effect -> Effect(value: MangaViewAction.mangaReadingViewAction(.userStartedReadingChapter))
                        // to download new pages. View itself doesn't disappear -> it doesn't appear, so we have to do it manually
                        return .merge(
                            Effect(value: MangaViewAction.computeNextAndPreviousChapterIndexes),
                            Effect(value: MangaViewAction.mangaReadingViewAction(.userStartedReadingChapter))
                        )
                        
                    case .userLeftMangaReadingView:
                        return Effect(value: MangaViewAction.userLeftMangaReadingView)
                        
                    default:
                        return .none
                }
                
            case .binding:
                return .none
        }
    }
)
