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
}

enum HomeAction {
    case onAppear
    case dataLoaded(Result<Response<[Manga]>, AppError>)
    case mangaThumbnailAction(id: UUID, action: OnlineMangaThumbnailAction)
    case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
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
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                if !state.mangaThumbnailStates.isEmpty { return .none }
                
                return env.homeClient.fetchHomePage()
                    .receive(on: DispatchQueue.main)
                    .catchToEffect(HomeAction.dataLoaded)
                
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
                
            case .mangaStatisticsFetched(let result):
                switch result {
                    case .success(let response):
                        for stat in response.statistics {
                            state.mangaThumbnailStates[id: stat.key]?.mangaState.statistics = stat.value
                        }
                        
                        return .none
                        
                    case .failure(let error):
                        switch error {
                            case .downloadError(let err):
                                print(err)
                            default:
                                break
                        }
                        return .none
                    }
                
            case .mangaThumbnailAction:
                return .none
        }
    }
)
