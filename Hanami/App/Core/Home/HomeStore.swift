//
//  HomeFeature.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation
import ComposableArchitecture
import Kingfisher

struct HomeState: Equatable {
    var lastUpdatedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var seasonalMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var awardWinningMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var mostFollowedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    
    var isRefreshActionInProgress = false
    var lastRefreshDate: Date?
}

enum HomeAction {
    case onAppear
    case refresh
    case refreshDelayCompleted
    case statisticsFetched(
        Result<MangaStatisticsContainer, AppError>, WritableKeyPath<HomeState, IdentifiedArrayOf<MangaThumbnailState>>
    )
    case mangaListFetched(
        Result<Response<[Manga]>, AppError>, WritableKeyPath<HomeState, IdentifiedArrayOf<MangaThumbnailState>>
    )
    
    case seasonalMangaListFetched(Result<Response<CustomMangaList>, AppError>)
    
    case userOpenedAwardWinningView
    case userOpenedMostFollowedView
    
    case mangaThumbnailAction(UUID, MangaThumbnailAction)
    case seasonalMangaThumbnailAction(UUID, MangaThumbnailAction)
    case awardWinningMangaThumbnailAction(UUID, MangaThumbnailAction)
    case mostFollowedMangaThumbnailAction(UUID, MangaThumbnailAction)
}

struct HomeEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
    let homeClient: HomeClient
    let cacheClient: CacheClient
    let imageClient: ImageClient
    let hudClient: HUDClient
    let hapticClient: HapticClient
}

let homeReducer = Reducer<HomeState, HomeAction, HomeEnvironment>.combine(
    mangaThumbnailReducer
        .forEach(
            state: \.lastUpdatedMangaThumbnailStates,
            action: /HomeAction.mangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    hapticClient: $0.hapticClient,
                    imageClient: $0.imageClient,
                    cacheClient: $0.cacheClient,
                    mangaClient: $0.mangaClient,
                    hudClient: $0.hudClient
                )
            }
        ),
    mangaThumbnailReducer
        .forEach(
            state: \.seasonalMangaThumbnailStates,
            action: /HomeAction.seasonalMangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    hapticClient: $0.hapticClient,
                    imageClient: $0.imageClient,
                    cacheClient: $0.cacheClient,
                    mangaClient: $0.mangaClient,
                    hudClient: $0.hudClient
                )
            }
        ),
    mangaThumbnailReducer
        .forEach(
            state: \.awardWinningMangaThumbnailStates,
            action: /HomeAction.awardWinningMangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    hapticClient: $0.hapticClient,
                    imageClient: $0.imageClient,
                    cacheClient: $0.cacheClient,
                    mangaClient: $0.mangaClient,
                    hudClient: $0.hudClient
                )
            }
        ),
    mangaThumbnailReducer
        .forEach(
            state: \.mostFollowedMangaThumbnailStates,
            action: /HomeAction.mostFollowedMangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    hapticClient: $0.hapticClient,
                    imageClient: $0.imageClient,
                    cacheClient: $0.cacheClient,
                    mangaClient: $0.mangaClient,
                    hudClient: $0.hudClient
                )
            }
        ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                guard state.lastUpdatedMangaThumbnailStates.isEmpty else { return .none }
                
                return .merge(
                    env.homeClient.fetchLastUpdates()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { HomeAction.mangaListFetched($0, \.lastUpdatedMangaThumbnailStates) },
                    
                    env.homeClient.fetchSeasonalTitlesList()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(HomeAction.seasonalMangaListFetched)
                    )
                
            case .refresh:
                let now = Date()
                
                guard state.lastRefreshDate == nil || now - state.lastRefreshDate! > 10 else {
                    env.hudClient.show(message: "Wait a little to refresh home page", backgroundColor: .yellow)
                    return env.hapticClient
                        .generateNotificationFeedback(.error)
                        .fireAndForget()
                }
                
                state.isRefreshActionInProgress = true
                state.lastRefreshDate = now
                
                var fetchedMangaIDs: [UUID] = []
                
                fetchedMangaIDs.append(contentsOf: state.awardWinningMangaThumbnailStates.map(\.id))
                fetchedMangaIDs.append(contentsOf: state.mostFollowedMangaThumbnailStates.map(\.id))
                
                state.awardWinningMangaThumbnailStates.removeAll()
                state.mostFollowedMangaThumbnailStates.removeAll()
                
                return .merge(
                    env.hapticClient.generateNotificationFeedback(.success).fireAndForget(),
                    
                    .cancel(ids: fetchedMangaIDs.map { OnlineMangaViewState.CancelClearCache(mangaID: $0) }),
                    
                    env.homeClient.fetchLastUpdates()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { HomeAction.mangaListFetched($0, \.lastUpdatedMangaThumbnailStates) },
                    
                    env.homeClient.fetchSeasonalTitlesList()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(HomeAction.seasonalMangaListFetched),
                    
                    Effect(value: .refreshDelayCompleted)
                        .delay(for: .seconds(3), scheduler: DispatchQueue.main)
                        .eraseToEffect()
                )
                
            case .refreshDelayCompleted:
                state.isRefreshActionInProgress = false
                return .none
                
            case .userOpenedAwardWinningView:
                guard state.awardWinningMangaThumbnailStates.isEmpty else { return .none }
                
                return env.homeClient.fetchAwardWinningManga()
                    .receive(on: DispatchQueue.main)
                    .catchToEffect { HomeAction.mangaListFetched($0, \.awardWinningMangaThumbnailStates) }
                
            case .userOpenedMostFollowedView:
                guard state.mostFollowedMangaThumbnailStates.isEmpty else { return .none }
                
                return env.homeClient.fetchMostFollowedManga()
                    .receive(on: DispatchQueue.main)
                    .catchToEffect { HomeAction.mangaListFetched($0, \.mostFollowedMangaThumbnailStates) }
                
            case .mangaListFetched(let result, let keyPath):
                switch result {
                    case .success(let response):
                        let mangaIDsList = state[keyPath: keyPath].map(\.id)
                        let fetchedMangaIDsList = response.data.map(\.id)
                        
                        guard mangaIDsList != fetchedMangaIDsList else {
                            env.hudClient.show(message: "Everything is up to date", backgroundColor: .green)
                            return .none
                        }
                        
                        state[keyPath: keyPath] = .init(
                            uniqueElements: response.data.map { MangaThumbnailState(manga: $0) }
                        )
                        
                        let coverArtURLs = state[keyPath: keyPath].compactMap(\.coverArtInfo?.coverArtURL256)
                        
                        return .merge(
                            env.homeClient.fetchStatistics(response.data.map(\.id))
                                .receive(on: DispatchQueue.main)
                                .catchToEffect { HomeAction.statisticsFetched($0, keyPath) },
                            
                            env.imageClient.prefetchImages(coverArtURLs, [.alsoPrefetchToMemory, .backgroundDecode])
                                .fireAndForget()
                        )
                            
                    case .failure(let error):
                        env.hudClient.show(message: error.description)
                        print("error: \(error)")
                        return env.hapticClient.generateNotificationFeedback(.error).fireAndForget()
                }
                
            case .statisticsFetched(let result, let keyPath):
                switch result {
                    case .success(let response):
                        for stat in response.statistics {
                            state[keyPath: keyPath][id: stat.key]?.onlineMangaState!.statistics = stat.value
                        }
                        
                        return .none
                        
                    case .failure(let error):
                        print("Error on fetching statistics on homeReducer: \(error)")
                        return .none
                }
                
            case .seasonalMangaListFetched(let result):
                switch result {
                    case .success(let response):
                        let mangaIDs = response.data.relationships.filter { $0.type == .manga }.map(\.id)
                        
                        return env.homeClient.fetchMangaByIDs(mangaIDs)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect { HomeAction.mangaListFetched($0, \.seasonalMangaThumbnailStates) }

                    case .failure(let error):
                        print("error: \(error)")
                        return .none
                }
                
            case .mangaThumbnailAction:
                return .none
                
            case .seasonalMangaThumbnailAction:
                return .none
                
            case .awardWinningMangaThumbnailAction:
                return .none
                
            case .mostFollowedMangaThumbnailAction:
                return .none
        }
    }
)
