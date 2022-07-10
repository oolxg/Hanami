//
//  HomeFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation
import ComposableArchitecture

struct HomeState: Equatable {
    var mangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
}

enum HomeAction {
    case onAppear
    case dataLoaded(Result<Response<[Manga]>, AppError>)
    case mangaThumbnailAction(id: UUID, action: MangaThumbnailAction)
    case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
}

struct HomeEnvironment {
    var loadHomePage: (JSONDecoder) -> Effect<Response<[Manga]>, AppError>
    var fetchStatistics: (_ mangaIDs: [UUID]) -> Effect<MangaStatisticsContainer, AppError>
    var databaseClient: DatabaseClient
}

let homeReducer = Reducer<HomeState, HomeAction, SystemEnvironment<HomeEnvironment>>.combine(
    mangaThumbnailReducer
        .forEach(
            state: \.mangaThumbnailStates,
            action: /HomeAction.mangaThumbnailAction,
            environment: {
                .live(
                    environment: .init(
                        loadThumbnailInfo: downloadThumbnailInfo,
                        databaseClient: $0.databaseClient
                    )
                )
            }
        ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                if !state.mangaThumbnailStates.isEmpty { return .none }
                
                return env.loadHomePage(env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(HomeAction.dataLoaded)
                
            case .dataLoaded(let result):
                switch result {
                    case .success(let response):
                        state.mangaThumbnailStates = .init(
                            uniqueElements: response.data.map { MangaThumbnailState(manga: $0) }
                        )
                        return env.fetchStatistics(response.data.map(\.id))
                            .receive(on: env.mainQueue())
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
