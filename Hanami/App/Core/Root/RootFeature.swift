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
        var isAppLocked = true
        var appLastTimeUsedAt: Date?
    }
    
    enum Tab: Equatable {
        case home, search, downloads, settings
    }
    
    enum Action {
        case tabChanged(Tab)
        case appAuthCompleted(Result<Void, AppError>)
        case scenePhaseChanged(ScenePhase)
        case homeAction(HomeFeature.Action)
        case searchAction(SearchFeature.Action)
        case downloadsAction(DownloadsFeature.Action)
        case settingsAction(SettingsFeature.Action)
    }
    
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.authClient) private var authClient
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .tabChanged(let newTab):
                state.selectedTab = newTab
                return newTab != .downloads ? .none : .task { .downloadsAction(.retrieveCachedManga) }
                
            case .scenePhaseChanged(let newScenePhase):
                defer { state.blurRadius = state.isAppLocked ? 10 : 0.00001 }
                
                switch newScenePhase {
                case .background:
                    state.appLastTimeUsedAt = .now
                    state.isAppLocked = true
                    return .none
                    
                case .inactive:
                    state.isAppLocked = true
                    return .none
                    
                case .active:
                    let autolockPolicy = settingsClient.getAutoLockPolicy()
                    
                    if autolockPolicy == .never {
                        state.isAppLocked = false
                        return .none
                    }

                    guard state.isAppLocked else { return .none }
                    
                    let now = Date()
                    
                    if let appLastUsed = state.appLastTimeUsedAt, Int(now - appLastUsed) < autolockPolicy.rawValue {
                        state.isAppLocked = false
                        return .none
                    }
                    
                    return authClient.makeAuth()
                        .receive(on: DispatchQueue.main)
                        .eraseToEffect(Action.appAuthCompleted)
                    
                @unknown default:
                    return .none
                }
                
            case .appAuthCompleted(let result):
                switch result {
                case .success:
                    state.appLastTimeUsedAt = .now
                    state.isAppLocked = false
                    state.blurRadius = 0.00001
                    return .none
                    
                case .failure:
                    return .none
                }
                
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
