//
//  HomeFeature.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation
import ComposableArchitecture
import ModelKit
import Utils
import DataTypeExtensions
import Logger
import ImageClient
import HUD
import HomeClient
import HapticClient

struct HomeFeature: Reducer {
    struct State: Equatable {
        var latestUpdatesMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var seasonalMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var awardWinningMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var mostFollowedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        
        var isRefreshActionInProgress = false
        var lastRefreshDate: Date?
        var seasonalMangaListID: UUID?
        var seasonalTabName: String?
    }
    
    enum Action {
        case onAppear
        case refreshButtonTapped
        case refreshDelayCompleted
        case statisticsFetched(
            Result<MangaStatisticsContainer, AppError>,
            WritableKeyPath<State, IdentifiedArrayOf<MangaThumbnailFeature.State>>
        )
        case mangaListFetched(
            Result<Response<[Manga]>, AppError>,
            WritableKeyPath<State, IdentifiedArrayOf<MangaThumbnailFeature.State>>
        )
        
        case seasonalMangaListFetched(Result<Response<CustomMangaList>, AppError>)
        
        case onAppearAwardWinningManga
        case onAppearMostFollewedManga
        
        case lastUpdatesMangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case seasonalMangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case awardWinningMangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case mostFollowedMangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
    }
    
    @Dependency(\.homeClient) private var homeClient
    @Dependency(\.hud) private var hud
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.mainQueue) private var mainQueue

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.latestUpdatesMangaThumbnailStates.isEmpty else { return .none }
                
                return .run { send in
                    let lastUpdateFetchResult = await homeClient.fetchLatestUpdatesManga()
                    await send(.mangaListFetched(lastUpdateFetchResult, \.latestUpdatesMangaThumbnailStates))
                    
                    let seasonalTitlesFetchResult = await homeClient.fetchSeasonalMangaList()
                    await send(.mangaListFetched(seasonalTitlesFetchResult, \.seasonalMangaThumbnailStates))
                }
                
            case .refreshButtonTapped:
                guard state.lastRefreshDate.isNil || .now - state.lastRefreshDate! > 10 else {
                    hud.show(
                        message: "Wait a little to refresh home page",
                        iconName: "clock",
                        backgroundColor: .theme.yellow
                    )
                    
                    hapticClient.generateNotificationFeedback(style: .error)
                    
                    return .none
                }
                
                state.isRefreshActionInProgress = true
                state.lastRefreshDate = .now
                
                var fetchedMangaIDs: [UUID] = []
                
                fetchedMangaIDs.append(contentsOf: state.awardWinningMangaThumbnailStates.map(\.id))
                fetchedMangaIDs.append(contentsOf: state.mostFollowedMangaThumbnailStates.map(\.id))
                fetchedMangaIDs.append(contentsOf: state.latestUpdatesMangaThumbnailStates.map(\.id))
                fetchedMangaIDs.append(contentsOf: state.seasonalMangaThumbnailStates.map(\.id))
                
                state.awardWinningMangaThumbnailStates.removeAll()
                state.mostFollowedMangaThumbnailStates.removeAll()
                
                struct UpdateDebounce: Hashable { }
                
                hapticClient.generateNotificationFeedback(style: .success)
                
                return .run { [seasonalListID = state.seasonalMangaListID] send in
                    let lastUpdateFetchResult = await homeClient.fetchLatestUpdatesManga()
                    await send(.mangaListFetched(lastUpdateFetchResult, \.latestUpdatesMangaThumbnailStates))
                    
                    if let seasonalListID {
                        let seasonalListFetchResult = await homeClient.fetchCustomMangaList(listID: seasonalListID)
                        await send(.seasonalMangaListFetched(seasonalListFetchResult))
                    }
                    
                    try await Task.sleep(seconds: 3)
                    await send(.refreshDelayCompleted)
                }
                
            case .refreshDelayCompleted:
                state.isRefreshActionInProgress = false
                return .none
                
            case .onAppearAwardWinningManga:
                guard state.awardWinningMangaThumbnailStates.isEmpty else { return .none }
                
                return .run { send in
                    let result = await homeClient.fetchAwardWinningManga()
                    await send(.mangaListFetched(result, \.awardWinningMangaThumbnailStates))
                }
                
            case .onAppearMostFollewedManga:
                guard state.mostFollowedMangaThumbnailStates.isEmpty else { return .none }
                
                return .run { send in
                    let result = await homeClient.fetchMostFollowedManga()
                    await send(.mangaListFetched(result, \.mostFollowedMangaThumbnailStates))
                }
                
            case .mangaListFetched(let result, let keyPath):
                switch result {
                case .success(let response):
                    let mangaIDsList = state[keyPath: keyPath].map(\.id)
                    
                    let range = 0..<min(response.data.count, 25)
                    
                    let fetchedMangaIDsList = Array(response.data.map(\.id)[range])
                    
                    guard mangaIDsList != fetchedMangaIDsList else {
                        return .none
                    }
                    
                    state[keyPath: keyPath] = response.data[range]
                        .map { MangaThumbnailFeature.State(manga: $0) }
                        .asIdentifiedArray
                    
                    let officialTestMangaID = UUID(uuidString: "f9c33607-9180-4ba6-b85c-e4b5faee7192")!
                    
                    state[keyPath: keyPath].remove(id: officialTestMangaID)
                    
                    let coverArtURLs = state[keyPath: keyPath].compactMap(\.thumbnailURL)
                    
                    imageClient.prefetchImages(with: coverArtURLs)
                    
                    return .run { send in
                        let result = await mangaClient.fetchStatistics(for: response.data.map(\.id))
                        await send(.statisticsFetched(result, keyPath))
                    }
                    
                case .failure(let error):
                    hud.show(message: error.description)
                    state.lastRefreshDate = nil
                    logger.error(
                        "Failed to load manga list: \(error)",
                        context: ["keyPath": "`\(keyPath.customDumpDescription)`"]
                    )
                    
                    hapticClient.generateNotificationFeedback(style: .error)
                    
                    return .none
                }
                
            case .statisticsFetched(let result, let keyPath):
                switch result {
                case .success(let response):
                    for stat in response.statistics {
                        state[keyPath: keyPath][id: stat.key]?.onlineMangaState?.statistics = stat.value
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to load statistics for manga list: \(error)",
                        context: ["keyPath": "`\(keyPath.customDumpDescription)`"]
                    )
                    return .none
                }
                
            case .seasonalMangaListFetched(let result):
                switch result {
                case .success(let response):
                    return .run { send in
                        let mangaIDs = response.data.relationships.filter { $0.type == .manga }.map(\.id)
                        let result = await homeClient.fetchManga(ids: mangaIDs)
                        await send(.mangaListFetched(result, \.seasonalMangaThumbnailStates))
                    }
                    
                case .failure(let error):
                    logger.error("Failed to load list of seasonal titles: \(error)")
                    return .none
                }
                
            case .lastUpdatesMangaThumbnailAction:
                return .none
                
            case .seasonalMangaThumbnailAction:
                return .none
                
            case .awardWinningMangaThumbnailAction:
                return .none
                
            case .mostFollowedMangaThumbnailAction:
                return .none
            }
        }
        .forEach(\.latestUpdatesMangaThumbnailStates, action: /Action.lastUpdatesMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        .forEach(\.seasonalMangaThumbnailStates, action: /Action.seasonalMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        .forEach(\.awardWinningMangaThumbnailStates, action: /Action.awardWinningMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        .forEach(\.mostFollowedMangaThumbnailStates, action: /Action.mostFollowedMangaThumbnailAction) {
            MangaThumbnailFeature()
        }
    }
}
