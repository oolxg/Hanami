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
    }
    
    enum Action: BindableAction {
        case initSettings
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.settingsClient) private var settingsClient
    
    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .initSettings:
                state.autoLockPolicy = settingsClient.getAutoLockPolicy()
                return .none
                
            case .binding(\.$autoLockPolicy):
                return settingsClient.setAutoLockPolicy(state.autoLockPolicy).fireAndForget()
                
            case .binding:
                return .none
            }
        }
    }
}
