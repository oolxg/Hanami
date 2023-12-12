//
//  HapticClient.swift
//  Hanami
//
//  Created by tatsuz0u
//  https://github.com/EhPanda-Team/EhPanda/blob/main/EhPanda/App/Tools/Clients/HapticClient.swift
//

import SwiftUI
import Dependencies
import Utils

extension DependencyValues {
    public var hapticClient: HapticClient {
        get { self[HapticClient.self] }
        set { self[HapticClient.self] = newValue }
    }
}

public struct HapticClient {
    public func generateFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        Task {
            HapticUtil.generateFeedback(style: style)
        }
    }
    
    public func generateNotificationFeedback(style: UINotificationFeedbackGenerator.FeedbackType) {
        Task {
            HapticUtil.generateNotificationFeedback(style: style)
        }
    }
}

extension HapticClient: DependencyKey {
    public static let liveValue = HapticClient()
}
