//
//  AppFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 03/07/2022.
//

import Foundation
import ComposableArchitecture

struct AppState: Equatable {
    var rootState: RootState
}

enum AppAction {
    case initApp
    case rootAction(RootAction)
}

struct AppEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
    let homeClient: HomeClient
    let searchClient: SearchClient
    let cacheClient: CacheClient
    let imageClient: ImageClient
    let hudClient: HUDClient
    let hapticClient: HapticClient
}

let appReducer: Reducer<AppState, AppAction, AppEnvironment> = .combine(
    rootReducer
        .pullback(
            state: \.rootState,
            action: /AppAction.rootAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient,
                    homeClient: $0.homeClient,
                    searchClient: $0.searchClient,
                    cacheClient: $0.cacheClient,
                    imageClient: $0.imageClient,
                    hudClient: $0.hudClient,
                    hapticClient: $0.hapticClient
                )
            }
        ),
    Reducer { _, action, env in
        switch action {
            case .initApp:
                return .concatenate(
//                  env.databaseClient.dropDatabase().fireAndForget()
                    env.databaseClient.prepareDatabase().fireAndForget(),
                    
                    Effect(value: .rootAction(.downloadsAction(.retrieveCachedManga)))
                )
                
            case .rootAction:
                return .none
        }
    }
)
