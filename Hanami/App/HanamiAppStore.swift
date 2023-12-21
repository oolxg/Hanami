//
//  AppFeature.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import ComposableArchitecture

@Reducer
struct AppFeature {
    struct State: Equatable {
        var rootState: RootFeature.State
    }
    
    enum Action {
        case initApp
        case rootAction(RootFeature.Action)
    }
    
    @Dependency(\.databaseClient) private var databaseClient

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .initApp:
                return .concatenate(
                    .run { _ in await databaseClient.prepareDatabase() },
                    
                    .merge(
                        .run { await $0(.rootAction(.downloadsAction(.initDownloads))) },
                            
                        .run { send in
                            await send(.rootAction(.settingsAction(.initSettings)))
                            
                            try await Task.sleep(seconds: 0.2)
                            
                            await send(.rootAction(.makeAuthIfNeeded))
                        },
                            
                        .run { await $0(.rootAction(.searchAction(.updateSearchHistory(nil)))) },
                            
                        .run { await $0(.rootAction(.searchAction(.filtersAction(.fetchFilterTagsIfNeeded)))) }
                    )
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
