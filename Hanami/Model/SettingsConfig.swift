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
    var readingFormat: ReadingFormat
    var iso639Language: ISO639Language
}

extension SettingsConfig {
    enum ReadingFormat: String {
        case leftToRight = "Left-to-Right"
        case rightToLeft = "Right-to-Left"
        case vertical = "Vertical"
    }
}

extension SettingsConfig.ReadingFormat: Codable { }
extension SettingsConfig.ReadingFormat: Equatable { }
extension SettingsConfig.ReadingFormat: CaseIterable { }
