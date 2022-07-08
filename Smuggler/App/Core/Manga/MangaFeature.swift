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

    var volumeTabStates: IdentifiedArrayOf<VolumeTabState> = []
    var areVolumesLoaded = false
    var shouldShowEmptyMangaMessage: Bool {
        areVolumesLoaded && volumeTabStates.isEmpty
    }
    
    var allCoverArtsInfo: [CoverArtInfo] = []

    var selectedTab: SelectedTab = .chapters
    enum SelectedTab: String, CaseIterable, Identifiable {
        case chapters = "Chapters"
        case about = "About"
        case coverArt = "Art"
        
        var id: String {
            rawValue
        }
    }
    
    @BindableState var hudInfo = HUDInfo()
    
    struct HUDInfo: Equatable {
        var show = false
        var message = ""
        var iconName: String?
        var backgroundColor = Color.theme.red
    }
    
    // MARK: - Props for reading view
    @BindableState var isUserOnReadingView = false
    // if user reads some chapter with scanlation group 'A', e.g. ch. 21
    // it means we have to get ch. 22(as next chapter) and 20(as previous) from the scanlation group 'A'
    // this indexes are array indexes in 'sameScanlationGroupChapters'
    var nextReadingChapterIndex: Int?
    var previousReadingChapterIndex: Int?
    
    var mangaReadingViewState: MangaReadingViewState? {
        // it's better not to set value of 'mangaReadingViewState' to nil
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
     
    var mainCoverArtURL: URL?
    var coverArtURLs: [URL] {
        allCoverArtsInfo.compactMap { coverArt in
            URL(
                string: "https://uploads.mangadex.org/covers/\(manga.id.uuidString.lowercased())/\(coverArt.attributes.fileName).256.jpg"
            )
        }
    }
    
    // should on be used for clearing cache
    mutating func reset() {
        let manga = manga
        let stat = statistics
        let coverArtURL = mainCoverArtURL
        
        self = MangaViewState(manga: manga)
        self.statistics = stat
        self.mainCoverArtURL = coverArtURL
    }
}

enum MangaViewAction: BindableAction {
    // MARK: - Actions to be called from view
    case onAppear
    case mangaTabChanged(MangaViewState.SelectedTab)

    // MARK: - Actions to be called from reducer
    case computeNextAndPreviousChapterIndexes
    case mangaStatisticsDownloaded(Result<MangaStatisticsContainer, AppError>)
    case volumesDownloaded(Result<VolumesContainer, AppError>)
    case sameScanlationGroupChaptersFetched(Result<VolumesContainer, AppError>)
    case allCoverArtsInfoFetched(Result<Response<[CoverArtInfo]>, AppError>)
    case userOpenedCoverArtSection
    
    // MARK: - Substate actions
    case volumeTabAction(volumeID: UUID, volumeAction: VolumeTabAction)
    case mangaReadingViewAction(MangaReadingViewAction)
    
    // MARK: - Binding
    case binding(BindingAction<MangaViewState>)
}

struct MangaViewEnvironment {
    var fetchChaptersFromExactScanlationGroup: (
        _ mangaID: UUID,
        _ scanlationGroup: UUID?,
        _ translatedLanguage: String?,
        _ decoder: JSONDecoder
    ) -> Effect<VolumesContainer, AppError>
    
    var fetchAllCoverArtsInfo: (UUID, JSONDecoder) -> Effect<Response<[CoverArtInfo]>, AppError>
    
    var fetchMangaStatistics: (_ mangaID: UUID) -> Effect<MangaStatisticsContainer, AppError>
}

let mangaViewReducer: Reducer<MangaViewState, MangaViewAction, SystemEnvironment<MangaViewEnvironment>> = .combine(
    volumeTabReducer.forEach(
        state: \.volumeTabStates,
        action: /MangaViewAction.volumeTabAction,
        environment: { _ in .live(
                environment: .init(
            ),
            isMainQueueAnimated: true
        ) }
    ),
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
                        env.fetchChaptersFromExactScanlationGroup(state.manga.id, nil, nil, env.decoder())
                            .receive(on: env.mainQueue())
                            .catchToEffect(MangaViewAction.volumesDownloaded)
                    )
                }
                        
                return effects.isEmpty ? .none : .merge(effects)
                
            case .userOpenedCoverArtSection:
                guard state.allCoverArtsInfo.isEmpty else {
                    return .none
                }
                
                return env.fetchAllCoverArtsInfo(state.manga.id, env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(MangaViewAction.allCoverArtsInfoFetched)
                
            case .mangaTabChanged(let newTab):
                state.selectedTab = newTab
                
                if newTab == .coverArt {
                    return Effect(value: MangaViewAction.userOpenedCoverArtSection)
                }
                
                return .none
                
            case .allCoverArtsInfoFetched(let result):
                switch result {
                    case .success(let response):
                        state.allCoverArtsInfo = response.data
                        return .none
                        
                    case .failure(let error):
                        print("error on fetching allCoverArtsInfo, \(error)")
                        return .none
                }

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
                
            // here we're handling users tap on chapter(means user wants to read chapter)
            case .volumeTabAction(_, .chapterAction(_, .userTappedOnChapterDetails(let chapter))):
                    // we're looking for action on chapters
                    // when user taps on some chapter, we send him to reading view
                state.mangaReadingViewState = MangaReadingViewState(
                    chapterID: chapter.id,
                    chapterIndex: chapter.attributes.chapterIndex
                )
                
                UITabBar.hideTabBar(animated: false)
                
                return env.fetchChaptersFromExactScanlationGroup(
                    state.manga.id,
                    chapter.scanltaionGroupID,
                    chapter.attributes.translatedLanguage,
                    env.decoder()
                )
                .receive(on: env.mainQueue())
                .catchToEffect(MangaViewAction.sameScanlationGroupChaptersFetched)
                
            case .volumeTabAction:
                return .none
                
            case .mangaReadingViewAction(.userHitLastPage):
                guard let nextChapterIndex = state.nextReadingChapterIndex,
                      let nextChapter = state.sameScanlationGroupChapters?[nextChapterIndex] else {
                    state.isUserOnReadingView = false
                    state.hudInfo.show = true
                    state.hudInfo.message = "🙁 This was the last chapter from this scanlation group."
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

            case .mangaReadingViewAction(.userHitTheMostFirstPage):
                guard let previousChapterIndex = state.previousReadingChapterIndex,
                      let previousChapter = state.sameScanlationGroupChapters?[previousChapterIndex] else {
                    state.isUserOnReadingView = false
                    state.hudInfo.show = true
                    state.hudInfo.message = "🤔 You've read the first chapter from this scanlation group."
                    return .none
                }
                
                state.mangaReadingViewState = MangaReadingViewState(
                    chapterID: previousChapter.id,
                    chapterIndex: previousChapter.chapterIndex,
                    shoudSendUserToTheLastPage: true
                )
                
                // we're firing this effect -> Effect(value: MangaViewAction.mangaReadingViewAction(.userStartedReadingChapter))
                // to download new pages. View itself doesn't disappear -> it doesn't appear, so we have to do it manually
                return .merge(
                    Effect(value: MangaViewAction.computeNextAndPreviousChapterIndexes),
                    Effect(value: MangaViewAction.mangaReadingViewAction(.userStartedReadingChapter))
                )
                
            case .mangaReadingViewAction(.userLeftMangaReadingView):
                UITabBar.showTabBar(animated: true)
                state.isUserOnReadingView = false
                return .none

            case .mangaReadingViewAction:
                return .none
                
            case .binding:
                return .none
        }
    }
    .binding()
)
