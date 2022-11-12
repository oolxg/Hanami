//
//  RootFeature.swift
//  Hanami
//
//  Created by Oleg on 12/05/2022.
//

import ComposableArchitecture
import enum SwiftUI.ScenePhase
import Foundation

struct RootFeature: ReducerProtocol {
    struct State: Equatable {
        var homeState = HomeFeature.State()
        var searchState = SearchFeature.State()
        var downloadsState = DownloadsFeature.State()
        var settingsState = SettingsFeature.State()
        
        var selectedTab: Tab
        var blurRadius: CGFloat = 0.0
    }
    
    enum Tab: Equatable {
        case home, search, downloads, settings
    }
    
    enum Action {
        case tabChanged(Tab)
        case scenePhaseChanged(ScenePhase)
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
                return newTab != .downloads ? .none : .task { .downloadsAction(.retrieveCachedManga) }
                
            case .scenePhaseChanged(let newScenePhase):
                state.blurRadius = newScenePhase == .active ? 0.00001 : 10
                
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
