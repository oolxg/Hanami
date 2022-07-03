//
//  RootFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/05/2022.
//

import Foundation
import ComposableArchitecture

struct RootState: Equatable {
    var homeState = HomeState()
    var searchState = SearchState()
    
    enum Tab: Equatable {
        case home, search
    }
    
    var selectedTab: Tab
}

enum RootAction {
    case tabChanged(RootState.Tab)
    case homeAction(HomeAction)
    case searchAction(SearchAction)
}

struct RootEnvironment {
    init() { }
}

let rootReducer = Reducer<RootState, RootAction, SystemEnvironment<RootEnvironment>>.combine(
    homeReducer
        .pullback(
            state: \.homeState,
            action: /RootAction.homeAction,
            environment: { _ in .live(
                environment: .init(
                    loadHomePage: downloadMangaList,
                    fetchStatistics: fetchMangaStatistics
                )
            ) }
        ),
    searchReducer
        .pullback(
            state: \.searchState,
            action: /RootAction.searchAction,
            environment: { _ in .live(
                    environment: .init(
                        searchManga: makeMangaSearchRequest,
                        fetchStatistics: fetchMangaStatistics
                    ),
                    isMainQueueAnimated: false
                )
            }
        ),
    Reducer { state, action, _ in
        switch action {
            case .tabChanged(let newTab):
                state.selectedTab = newTab
                return .none
                
            case .homeAction:
                return .none
                
            case .searchAction:
                return .none
        }
    }
)
