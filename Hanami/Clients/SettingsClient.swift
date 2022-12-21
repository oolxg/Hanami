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
    /// Save `SettingsConfig` in `UserDefaults`
    ///
    /// - Parameter config: `SettingsConfig` to be saved
    /// - Returns: `EffectTask<Never>` - returns nothing, basically...
    let saveSettingsConfig: (_ config: SettingsConfig) -> EffectTask<Never>
    /// Retrieve `SettingsConfig` from `UserDefaults`
    ///
    /// - Returns: `Effect<SettingsConfig, AppError>` - returns either `SettingsConfig` or `AppError.notFound`
    let getSettingsConfig: () -> Effect<SettingsConfig, AppError>
}

extension SettingsClient: DependencyKey {
    static let liveValue = SettingsClient(
        saveSettingsConfig: { config in
            .fireAndForget {
                UserDefaults.standard.set(config.toData(), forKey: Defaults.Storage.settingsConfig)
            }
        },
        getSettingsConfig: {
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
