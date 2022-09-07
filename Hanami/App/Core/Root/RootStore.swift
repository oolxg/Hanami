//
//  RootFeature.swift
//  Hanami
//
//  Created by Oleg on 12/05/2022.
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
    let hapticClient: HapticClient
    let searchClient: SearchClient
    let cacheClient: CacheClient
    let imageClient: ImageClient
    let mangaClient: MangaClient
    let homeClient: HomeClient
    let hudClient: HUDClient
}

let rootReducer = Reducer<RootState, RootAction, RootEnvironment>.combine(
    homeReducer
        .pullback(
            state: \.homeState,
            action: /RootAction.homeAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    hapticClient: $0.hapticClient,
                    cacheClient: $0.cacheClient,
                    imageClient: $0.imageClient,
                    mangaClient: $0.mangaClient,
                    homeClient: $0.homeClient,
                    hudClient: $0.hudClient
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
                    hapticClient: $0.hapticClient,
                    searchClient: $0.searchClient,
                    cacheClient: $0.cacheClient,
                    imageClient: $0.imageClient,
                    mangaClient: $0.mangaClient,
                    hudClient: $0.hudClient
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
                    hapticClient: $0.hapticClient,
                    cacheClient: $0.cacheClient,
                    imageClient: $0.imageClient,
                    mangaClient: $0.mangaClient,
                    hudClient: $0.hudClient
                )
            }
        ),
    Reducer { state, action, _ in
        switch action {
            case .tabChanged(let newTab):
                state.selectedTab = newTab
                
                if newTab == .downloads {
                    return Effect(value: .downloadsAction(.retrieveCachedManga))
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
