//
//  SettingsStore.swift
//  Hanami
//
//  Created by Oleg on 10/10/2022.
//

import Foundation
import ComposableArchitecture


struct SettingsFeature: ReducerProtocol {
    struct State: Equatable {
        @BindableState var autoLockPolicy: AutoLockPolicy = .never
        @BindableState var blurRadius = 0.0
    }
    
    enum Action: BindableAction {
        case initSettings
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.hapticClient) private var hapticClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .initSettings:
                state.autoLockPolicy = settingsClient.getAutoLockPolicy()
                state.blurRadius = settingsClient.getBlurRadius()
                return .none
                
            case .binding(\.$autoLockPolicy):
                var effects: [Effect<Action, Never>] = [
                    settingsClient.setAutoLockPolicy(state.autoLockPolicy).fireAndForget()
                ]
                
                if state.autoLockPolicy != .never && state.blurRadius == Defaults.Security.minBlurRadius {
                    state.blurRadius = Defaults.Security.blurRadiusStep
                    effects.append(settingsClient.setBlurRadius(state.blurRadius).fireAndForget())
                }
                
                return .merge(effects)

            case .binding(\.$blurRadius):
                var effects: [Effect<Action, Never>] = [
                    settingsClient.setBlurRadius(state.blurRadius).fireAndForget()
                ]
                
                if state.blurRadius == Defaults.Security.minBlurRadius {
                    state.autoLockPolicy = .never
                    effects.append(
                        settingsClient.setAutoLockPolicy(state.autoLockPolicy).fireAndForget()
                    )
                }
                
                return .merge(effects)
                
            case .binding:
                return .none
            }
        }
    }
}
