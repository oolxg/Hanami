//
//  SettingsConfig.swift
//  Hanami
//
//  Created by Oleg Mihajlov on 19.11.22.
//

import Foundation

struct SettingsConfig: Codable {
    let autolockPolicy: AutoLockPolicy
    let blurRadius: Double
    let useHighResImagesForOnlineReading: Bool
    let useHighResImagesForCaching: Bool
}

extension SettingsConfig: Equatable { }
