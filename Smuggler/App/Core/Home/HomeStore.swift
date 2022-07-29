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
    var mangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var seasonalMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var awardWinningMangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
}

enum HomeAction {
    case onAppear
    case dataLoaded(Result<Response<[Manga]>, AppError>)
    
    case mangaThumbnailAction(UUID, MangaThumbnailAction)
    case seasonalMangaThumbnailAction(UUID, MangaThumbnailAction)
    case awardWinningMangaThumbnailAction(UUID, MangaThumbnailAction)
    
    case seasonalMangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
    
    case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
    case seasonalMangaListFetched(Result<Response<CustomMangaList>, AppError>)
    
    case seasonalMangaFetched(Result<Response<[Manga]>, AppError>)
    case awardWinningMangaFetched(Result<Response<[Manga]>, AppError>)
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
            state: \.mangaThumbnailStates,
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
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                if !state.mangaThumbnailStates.isEmpty { return .none }
                
                return .merge(
                    env.homeClient.fetchHomePage()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(HomeAction.dataLoaded),
                    
                    env.homeClient.fetchSeasonalTitlesList()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(HomeAction.seasonalMangaListFetched),
                    
                    env.homeClient.fetchAwardWinningManga()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(HomeAction.awardWinningMangaFetched)
                    )
                
            case .dataLoaded(let result):
                switch result {
                    case .success(let response):
                        state.mangaThumbnailStates = .init(
                            uniqueElements: response.data.map { MangaThumbnailState(manga: $0) }
                        )
                        
                        return env.homeClient.fetchStatistics(response.data.map(\.id))
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(HomeAction.mangaStatisticsFetched)
                        
                    case .failure(let error):
                        print("error on fetching statistics: \(error)")
                        return .none
                }
                
            case .awardWinningMangaFetched(let result):
                switch result {
                    case .success(let response):
                        state.awardWinningMangaThumbnailStates = .init(
                            uniqueElements: response.data.map { MangaThumbnailState(manga: $0) }
                        )
                        
                        return .none
                        
                    case .failure(let error):
                        print("error: \(error)")
                        return .none
                }
                
            case .mangaStatisticsFetched(let result):
                switch result {
                    case .success(let response):
                        for stat in response.statistics {
                            state.mangaThumbnailStates[id: stat.key]?.onlineMangaState!.statistics = stat.value
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
                            .catchToEffect(HomeAction.seasonalMangaFetched)
                        
                    case .failure(let error):
                        print("error: \(error)")
                        return .none
                }
                
            case .seasonalMangaFetched(let result):
                switch result {
                    case .success(let response):
                        state.seasonalMangaThumbnailStates = .init(
                            uniqueElements: response.data.map { MangaThumbnailState(manga: $0) }
                        )

                        return env.homeClient.fetchStatistics(response.data.map(\.id))
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(HomeAction.seasonalMangaStatisticsFetched)
                        
                    case .failure(let error):
                        print("error: \(error)")
                        return .none
                }
                
            case .seasonalMangaStatisticsFetched(let result):
                switch result {
                    case .success(let response):
                        for stat in response.statistics {
                            state.seasonalMangaThumbnailStates[id: stat.key]?.onlineMangaState!.statistics = stat.value
                        }
                        
                        return .none
                        
                    case .failure(let error):
                        print("Error on fetching statistics on homeReducer: \(error)")
                        return .none
                }
                
            case .mangaThumbnailAction:
                return .none
                
            case .seasonalMangaThumbnailAction:
                return .none
                
            case .awardWinningMangaThumbnailAction:
                return .none
        }
    }
)
