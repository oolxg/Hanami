//
//  SettingsClient.swift
//  Hanami
//
//  Created by Oleg on 13/10/2022.
//

import ComposableArchitecture
import Combine
import LocalAuthentication

extension DependencyValues {
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}

struct SettingsClient {
    let setAutoLockPolicy: (_ policy: AutoLockPolicy) -> Effect<Never, Never>
    let getAutoLockPolicy: () -> AutoLockPolicy
    let setBlurRadius: (_ newRadius: Double) -> Effect<Never, Never>
    let getBlurRadius: () -> Double
}

extension SettingsClient: DependencyKey {
    static let liveValue = SettingsClient(
        setAutoLockPolicy: { policy in
            .fireAndForget {
                UserDefaults.standard.set(policy.rawValue, forKey: Defaults.Security.autolockPolicy)
            }
        },
        getAutoLockPolicy: {
            let rawValue = UserDefaults.standard.integer(forKey: Defaults.Security.autolockPolicy)
            
            return AutoLockPolicy(rawValue: rawValue)
        },
        setBlurRadius: { newBlurRadius in
            .fireAndForget {
                UserDefaults.standard.set(newBlurRadius, forKey: Defaults.Security.blurRadius)
            }
        },
        getBlurRadius: {
            let fetched = UserDefaults.standard.double(forKey: Defaults.Security.blurRadius)
            return fetched == 0 ? Defaults.Security.minBlurRadius : fetched
        }
    )
}
