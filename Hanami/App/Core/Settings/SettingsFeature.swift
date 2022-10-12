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
    }
    
    enum Action {
        case test
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { _, action in
            switch action {
                case .test:
                    print("hello")
                    return .none
            }
        }
    }
}
