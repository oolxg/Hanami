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
    var downloadsState = DownloadsState()
    
    enum Tab: Equatable {
        case home, search, downloads
    }
    
    var selectedTab: Tab
}

enum RootAction {
    case tabChanged(RootState.Tab)
    case homeAction(HomeAction)
    case searchAction(SearchAction)
    case downloadsAction(DownloadsAction)
}

struct RootEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
    let homeClient: HomeClient
    let searchClient: SearchClient
}

let rootReducer = Reducer<RootState, RootAction, RootEnvironment>.combine(
    homeReducer
        .pullback(
            state: \.homeState,
            action: /RootAction.homeAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient,
                    homeClient: $0.homeClient
                )
            }
        ),
    searchReducer
        .pullback(
            state: \.searchState,
            action: /RootAction.searchAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient,
                    searchClient: $0.searchClient
                )
            }
        ),
    downloadsReducer
        .pullback(
            state: \.downloadsState,
            action: /RootAction.downloadsAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    mangaClient: $0.mangaClient
                )
            }
        ),
    Reducer { state, action, _ in
        switch action {
            case .tabChanged(let newTab):
                state.selectedTab = newTab
                
                if newTab == .downloads {
                    return Effect(value: RootAction.downloadsAction(.fetchCachedManga))
                }
                
                return .none
                
            case .homeAction:
                return .none
                
            case .searchAction:
                return .none
                
            case .downloadsAction:
                return .none
        }
    }
)
