//
//  HomeFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation
import ComposableArchitecture
import Kingfisher

struct HomeState: Equatable {
    var lastUpdatedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var seasonalMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var awardWinningMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var mostFollowedMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
}

enum HomeAction {
    case onAppear
    
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
}

let homeReducer = Reducer<HomeState, HomeAction, HomeEnvironment>.combine(
    mangaThumbnailReducer
        .forEach(
            state: \.lastUpdatedMangaThumbnailStates,
            action: /HomeAction.mangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient,
                    cacheClient: $0.cacheClient
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
                    mangaClient: $0.mangaClient,
                    cacheClient: $0.cacheClient
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
                    mangaClient: $0.mangaClient,
                    cacheClient: $0.cacheClient
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
                    mangaClient: $0.mangaClient,
                    cacheClient: $0.cacheClient
                )
            }
        ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                if !state.lastUpdatedMangaThumbnailStates.isEmpty { return .none }
                
                return .merge(
                    env.homeClient.fetchLastUpdates()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { HomeAction.mangaListFetched($0, \.lastUpdatedMangaThumbnailStates) },
                    
                    env.homeClient.fetchSeasonalTitlesList()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(HomeAction.seasonalMangaListFetched)
                    )
                
            case .userOpenedAwardWinningView:
                guard state.awardWinningMangaThumbnailStates.isEmpty else { return .none }
                
                return env.homeClient.fetchAwardWinningManga()
                    .receive(on: DispatchQueue.main)
                    .catchToEffect { HomeAction.mangaListFetched($0, \.awardWinningMangaThumbnailStates) }
                
            case .userOpenedMostFollowedView:
                guard state.mostFollowedMangaThumbnailStates.isEmpty else { return .none }
                
                return env.homeClient.fetchMostFollewManga()
                    .receive(on: DispatchQueue.main)
                    .catchToEffect { HomeAction.mangaListFetched($0, \.mostFollowedMangaThumbnailStates) }
                
            case .mangaListFetched(let result, let keyPath):
                switch result {
                    case .success(let response):
                        state[keyPath: keyPath] = .init(
                            uniqueElements: response.data.map { MangaThumbnailState(manga: $0) }
                        )
                        
                        return env.homeClient.fetchStatistics(response.data.map(\.id))
                            .receive(on: DispatchQueue.main)
                            .catchToEffect { HomeAction.statisticsFetched($0, keyPath) }
                        
                    case .failure(let error):
                        print("error: \(error)")
                        return .none
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
