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
    let saveSettingsConfig: (_ config: SettingsConfig) -> Effect<Never, Never>
    let getSettingsConfig: () -> Effect<SettingsConfig, AppError>
}

extension SettingsClient: DependencyKey {
    static let liveValue = SettingsClient(
        saveSettingsConfig: { config in
            .fireAndForget {
                UserDefaults.standard.set(config.toData(), forKey: Defaults.Security.settingsConfig)
            }
        },
        getSettingsConfig: {
            Future { promise in
                guard let cfgData = UserDefaults.standard.object(forKey: Defaults.Security.settingsConfig) as? Data,
                      let config = try? JSONDecoder().decode(SettingsConfig.self, from: cfgData) else {
                    return promise(.failure(AppError.notFound))
                }
                
                promise(.success(config))
            }
            .eraseToEffect()
        })
}
