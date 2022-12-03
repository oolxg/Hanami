//
//  SettingsConfig.swift
//  Hanami
//
//  Created by Oleg on 21.11.22.
//

import Foundation

struct SettingsConfig: Codable, Equatable {
    var autolockPolicy: AutoLockPolicy
    var blurRadius: Double
    var useHigherQualityImagesForOnlineReading: Bool
    var useHigherQualityImagesForCaching: Bool
    // 0 - system, 1 - light, 2 - dark
    var colorScheme: Int
}
