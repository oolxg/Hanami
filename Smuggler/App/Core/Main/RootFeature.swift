//
//  RootFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/05/2022.
//

import Foundation
import ComposableArchitecture

struct AppState: Equatable {
    var homeState = HomeState()
    
    enum Tab: Equatable {
        case home
    }
    
    var selectedTab: Tab
}

enum AppAction: Equatable {
    case tabChanged(AppState.Tab)
    case homeAction(HomeAction)
}

struct AppEnvironment {
    init() { }
}

let appReducer = Reducer<AppState, AppAction, SystemEnvironment<AppEnvironment>>.combine(
    homeReducer
        .pullback(
            state: \.homeState,
            action: /AppAction.homeAction,
            environment: { _ in .live(environment: .init(loadHomePage: downloadMangaList)) }
        ),
    Reducer { state, action, env in
        switch action {
            case .tabChanged(let newTab):
                state.selectedTab = newTab
                return .none
            case .homeAction(_):
                return .none
        }
    }
)
