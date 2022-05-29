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
    var searchState = SearchState()
    
    enum Tab: Equatable {
        case home, search
    }
    
    var selectedTab: Tab
}

enum AppAction: Equatable {
    case tabChanged(AppState.Tab)
    case homeAction(HomeAction)
    case searchAction(SearchAction)
}

struct AppEnvironment {
    init() { }
}

let appReducer = Reducer<AppState, AppAction, SystemEnvironment<AppEnvironment>>.combine(
    homeReducer
        .pullback(
            state: \.homeState,
            action: /AppAction.homeAction,
            environment: { _ in .live(
                environment: .init(
                    loadHomePage: downloadMangaList
                )
            ) }
        ),
    searchReducer
        .pullback(
            state: \.searchState,
            action: /AppAction.searchAction,
            environment: { _ in
                    .live(
                        environment: .init(
                            searchManga: makeMangaSearchRequest,
                            getListOfTags: downloadTagsList
                        ),
                        isMainQueueWithAnimation: true
                    )
            }
        ),
    Reducer { state, action, env in
        switch action {
            case .tabChanged(let newTab):
                state.selectedTab = newTab
                return .none
            case .homeAction(_):
                return .none
            case .searchAction(_):
                return .none
        }
    }
)
