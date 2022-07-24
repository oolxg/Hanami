//
//  HomeFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation
import ComposableArchitecture

struct HomeState: Equatable {
    var mangaThumbnailStates: IdentifiedArrayOf<OnlineMangaThumbnailState> = []
    var seasonalMangaThumbnailStates: IdentifiedArrayOf<OnlineMangaThumbnailState> = []
    var awardWinningMangaThumbnailStates: IdentifiedArrayOf<OnlineMangaThumbnailState> = []
}

enum HomeAction {
    case onAppear
    case dataLoaded(Result<Response<[Manga]>, AppError>)
    
    case mangaThumbnailAction(id: UUID, action: OnlineMangaThumbnailAction)
    case seasonalMangaThumbnailAction(id: UUID, action: OnlineMangaThumbnailAction)
    case awardWinningMangaThumbnailAction(id: UUID, action: OnlineMangaThumbnailAction)
    
    case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
    case seasonalMangaListFetched(Result<Response<CustomMangaList>, AppError>)
    
    case seasonalMangaFetched(Result<Response<[Manga]>, AppError>)
    case awardWinningMangaFetched(Result<Response<[Manga]>, AppError>)
}

struct HomeEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
    let homeClient: HomeClient
}

let homeReducer = Reducer<HomeState, HomeAction, HomeEnvironment>.combine(
    onlineMangaThumbnailReducer
        .forEach(
            state: \.mangaThumbnailStates,
            action: /HomeAction.mangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient
                )
            }
        ),
    onlineMangaThumbnailReducer
        .forEach(
            state: \.seasonalMangaThumbnailStates,
            action: /HomeAction.seasonalMangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient
                )
            }
        ),
    onlineMangaThumbnailReducer
        .forEach(
            state: \.awardWinningMangaThumbnailStates,
            action: /HomeAction.awardWinningMangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient
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
                            uniqueElements: response.data.map { OnlineMangaThumbnailState(manga: $0) }
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
                            uniqueElements: response.data.map { OnlineMangaThumbnailState(manga: $0) }
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
                            state.mangaThumbnailStates[id: stat.key]?.mangaState.statistics = stat.value
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
                            uniqueElements: response.data.map { OnlineMangaThumbnailState(manga: $0) }
                        )
                        
//                        let t = CoverArtInfo(
//                            id: UUID(), type: .coverArt, attributes: <#T##Attributes#>, relationships: <#T##[Relationship]#>)
                        print(response.data.first!.relationships.filter { $0.type == .coverArt })
                        
                        return .none
                        
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
        }
    }
)
