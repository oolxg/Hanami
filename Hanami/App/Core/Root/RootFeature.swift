//
//  RootFeature.swift
//  Hanami
//
//  Created by Oleg on 12/05/2022.
//

import ComposableArchitecture

struct RootFeature: ReducerProtocol {
    struct State: Equatable {
        var homeState = HomeFeature.State()
        var searchState = SearchFeature.State()
        var downloadsState = DownloadsFeature.State()
        var settingsState = SettingsFeature.State()
        
        enum Tab: Equatable {
            case home, search, downloads, settings
        }
        
        var selectedTab: Tab
    }
    
    enum Action {
        case tabChanged(RootFeature.State.Tab)
        case homeAction(HomeFeature.Action)
        case searchAction(SearchFeature.Action)
        case downloadsAction(DownloadsFeature.Action)
        case settingsAction(SettingsFeature.Action)
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
                case .tabChanged(let newTab):
                    state.selectedTab = newTab
                    
                    if newTab == .downloads {
                        return .task { .downloadsAction(.retrieveCachedManga) }
                    }
                    
                    return .none
                    
                case .homeAction:
                    return .none
                    
                case .searchAction:
                    return .none
                    
                case .downloadsAction:
                    return .none
                    
                case .settingsAction:
                    return .none
            }
        }
        Scope(state: \.homeState, action: /Action.homeAction) {
            HomeFeature()
        }
        Scope(state: \.downloadsState, action: /Action.downloadsAction) {
            DownloadsFeature()
        }
        Scope(state: \.searchState, action: /Action.searchAction) {
            SearchFeature()
        }
        Scope(state: \.settingsState, action: /Action.settingsAction) {
            SettingsFeature()
        }
    }
}
