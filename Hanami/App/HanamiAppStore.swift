//
//  AppFeature.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

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
                    databaseClient.prepareDatabase().fireAndForget(),
                    
                    .merge(
                        .run { await $0(.rootAction(.downloadsAction(.initDownloads))) },
                            
                        .run { await $0(.rootAction(.settingsAction(.initSettings))) },
                            
                        .run { await $0(.rootAction(.searchAction(.updateSearchHistory(nil)))) },
                            
                        .run { await $0(.rootAction(.searchAction(.filtersAction(.fetchFilterTagsIfNeeded)))) }
                    ),
                    
                    .run { await $0(.rootAction(.makeAuthIfNeeded)) }
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
