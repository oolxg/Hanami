//
//  SettingsClient.swift
//  Hanami
//
//  Created by Oleg on 13/10/2022.
//

import Dependencies
import ModelKit
import Utils
import Foundation
import typealias IdentifiedCollections.IdentifiedArrayOf

public extension DependencyValues {
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}

public struct SettingsClient {
    public func updateSettingsConfig(_ config: SettingsConfig) {
        Task {
            let data = try? AppUtil.encoder.encode(config)
            UserDefaults.standard.set(data, forKey: Defaults.Storage.settingsConfig)
        }
    }
    
    public func retireveSettingsConfig() async -> Result<SettingsConfig, AppError> {
        let task = Task {
            let data = UserDefaults.standard.object(forKey: Defaults.Storage.settingsConfig) as? Data
            
            guard let data, let config = try? AppUtil.decoder.decode(SettingsConfig.self, from: data) else {
                throw AppError.notFound
            }
            
            return config
        }
        
        do {
            return .success(try await task.value)
        } catch {
            return .failure(AppError.notFound)
        }
    }
}

extension SettingsClient: DependencyKey {
    public static let liveValue = SettingsClient()
}
