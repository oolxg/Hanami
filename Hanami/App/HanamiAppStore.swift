//
//  AppFeature.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import Foundation
import ComposableArchitecture

struct AppFeature: ReducerProtocol {
    struct State: Equatable {
        var rootState: RootFeature.State
    }
    
    enum Action {
        case initApp
        case rootAction(RootFeature.Action)
    }
    
    @Dependency(\.databaseClient) private var databaseClient

    var body: some ReducerProtocol<State, Action> {
        Reduce { _, action in
            switch action {
                case .initApp:
                    return .concatenate(
//                        env.databaseClient.dropDatabase().fireAndForget(),
                        databaseClient.prepareDatabase().fireAndForget(),
                        
                        .task { .rootAction(.downloadsAction(.retrieveCachedManga)) }
                    )
                    
                case .rootAction:
                    return .none
            }
        }
        Scope(state: \.rootState, action: /Action.rootAction) {
            RootFeature()
        }
    }
}
