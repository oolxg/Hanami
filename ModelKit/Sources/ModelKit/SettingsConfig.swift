//
//  SettingsConfig.swift
//  Hanami
//
//  Created by Oleg on 21.11.22.
//

import Foundation

public struct SettingsConfig: Codable, Equatable {
    public var autolockPolicy: AutoLockPolicy
    public var blurRadius: Double
    public var useHigherQualityImagesForOnlineReading: Bool
    public var useHigherQualityImagesForCaching: Bool
    // 0 - system, 1 - light, 2 - dark
    public var colorScheme: Int
    public var readingFormat: ReadingFormat
    public var iso639Language: ISO639Language
    
    public init(
        autolockPolicy: AutoLockPolicy,
        blurRadius: Double,
        useHigherQualityImagesForOnlineReading: Bool,
        useHigherQualityImagesForCaching: Bool,
        colorScheme: Int,
        readingFormat: ReadingFormat,
        iso639Language: ISO639Language
    ) {
        self.autolockPolicy = autolockPolicy
        self.blurRadius = blurRadius
        self.useHigherQualityImagesForOnlineReading = useHigherQualityImagesForOnlineReading
        self.useHigherQualityImagesForCaching = useHigherQualityImagesForCaching
        self.colorScheme = colorScheme
        self.readingFormat = readingFormat
        self.iso639Language = iso639Language
    }
}

public extension SettingsConfig {
    enum ReadingFormat: String {
        case leftToRight = "Left-to-Right"
        case rightToLeft = "Right-to-Left"
        case vertical = "Vertical"
    }
}

extension SettingsConfig.ReadingFormat: Codable { }
extension SettingsConfig.ReadingFormat: Equatable { }
extension SettingsConfig.ReadingFormat: CaseIterable { }
