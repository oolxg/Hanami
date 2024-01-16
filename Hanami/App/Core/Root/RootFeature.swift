//
//  RootFeature.swift
//  Hanami
//
//  Created by Oleg on 12/05/2022.
//

import ComposableArchitecture
import enum SwiftUI.ScenePhase
import Foundation
import Utils
import DataTypeExtensions
import Logger
import AuthClient

@Reducer
struct RootFeature {
    struct State: Equatable {
        var homeState = HomeFeature.State()
        var searchState = SearchFeature.State()
        var downloadsState = DownloadsFeature.State()
        var settingsState = SettingsFeature.State()
        
        var selectedTab: Tab = .home
        var isAppLocked = true
        var appLastUsedAt: Date?
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
        
        case makeAuthIfNeeded
    }
    
    @Dependency(\.authClient) private var authClient
    @Dependency(\.logger) private var logger

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            struct CancelAuth: Hashable { }
            switch action {
            case .tabChanged(let newTab):
                state.selectedTab = newTab
                
                switch newTab {
                case .settings:
                    return .run { await $0(.settingsAction(.recomputeCacheSize)) }
                case .downloads:
                    return .run { await $0(.downloadsAction(.initDownloads)) }
                default:
                    return .none
                }
                
            case .scenePhaseChanged(let newScenePhase):
                switch newScenePhase {
                case .background:
                    state.appLastUsedAt = .now
                    state.isAppLocked = true
                    return .cancel(id: CancelAuth())
                    
                case .inactive:
                    state.isAppLocked = true
                    return .none
                    
                case .active:
                    let autolockPolicy = state.settingsState.autolockPolicy
                    
                    if autolockPolicy == .never {
                        state.isAppLocked = false
                    }
                    
                    if let appLastUsed = state.appLastUsedAt, Int(.now - appLastUsed) < autolockPolicy.autolockDelay {
                        state.isAppLocked = false
                    }

                    guard state.isAppLocked else { return .none }
                    
                    return .run { send in
                        await withTaskCancellation(id: CancelAuth(), cancelInFlight: true) {
                            let result = await authClient.makeAuth()
                            await send(.appAuthCompleted(result))
                        }
                    }
                    
                @unknown default:
                    logger.info("New ScenePhase arrived!")
                    return .none
                }
                
            case .makeAuthIfNeeded:
                guard state.settingsState.autolockPolicy != .never else {
                    state.isAppLocked = false
                    return .none
                }
                
                return .run { send in
                    await withTaskCancellation(id: CancelAuth(), cancelInFlight: true) {
                        let result = await authClient.makeAuth()
                        await send(.appAuthCompleted(result))
                    }
                }
                
            case .appAuthCompleted(let result):
                if case .success = result {
                    state.appLastUsedAt = .now
                    state.isAppLocked = false
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
