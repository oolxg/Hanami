//
//  SettingsClient.swift
//  Hanami
//
//  Created by Oleg on 13/10/2022.
//

import ComposableArchitecture
import Combine
import LocalAuthentication
import ModelKit
import Utils

extension DependencyValues {
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}

struct SettingsClient {
    /// Save `SettingsConfig` in `UserDefaults`
    ///
    /// - Parameter config: `SettingsConfig` to be saved
    /// - Returns: `EffectTask<Never>` - returns nothing, basically...
    let updateSettingsConfig: (_ config: SettingsConfig) -> EffectTask<Never>
    /// Retrieve `SettingsConfig` from `UserDefaults`
    ///
    /// - Returns: `Effect<SettingsConfig, AppError>` - returns either `SettingsConfig` or `AppError.notFound`
    let retireveSettingsConfig: () -> EffectPublisher<SettingsConfig, AppError>
}

extension SettingsClient: DependencyKey {
    static let liveValue = SettingsClient(
        updateSettingsConfig: { newConfig in
            .fireAndForget {
                UserDefaults.standard.set(newConfig.toData(), forKey: Defaults.Storage.settingsConfig)
            }
        },
        retireveSettingsConfig: {
            Future { promise in
                let data = UserDefaults.standard.object(forKey: Defaults.Storage.settingsConfig) as? Data
                
                guard let data, let config = try? AppUtil.decoder.decode(SettingsConfig.self, from: data) else {
                    return promise(.failure(.notFound))
                }
                
                promise(.success(config))
            }
            .eraseToEffect()
        })
}
