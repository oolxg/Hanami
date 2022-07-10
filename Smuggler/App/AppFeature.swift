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
    var databaseClient: DatabaseClient
}

let appReducer: Reducer<AppState, AppAction, AppEnvironment> = .combine(
    rootReducer
        .pullback(
            state: \.rootState,
            action: /AppAction.rootAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient
                )
            }
        ),
    Reducer { _, action, env in
        switch action {
            case .initApp:
                return env.databaseClient.dropDatabase().fireAndForget()
//                    env.databaseClient.prepareDatabase()
                
            case .rootAction:
                return .none
        }
    }
)
