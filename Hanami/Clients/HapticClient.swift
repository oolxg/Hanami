//
//  HapticClient.swift
//  Hanami
//
//  Created by tatsuz0u
//  https://github.com/EhPanda-Team/EhPanda/blob/main/EhPanda/App/Tools/Clients/HapticClient.swift
//

import SwiftUI
import ComposableArchitecture

extension DependencyValues {
    var hapticClient: HapticClient {
        get { self[HapticClient.self] }
        set { self[HapticClient.self] = newValue }
    }
}

struct HapticClient {
    let generateFeedback: (UIImpactFeedbackGenerator.FeedbackStyle) -> Effect<Never, Never>
    let generateNotificationFeedback: (UINotificationFeedbackGenerator.FeedbackType) -> Effect<Never, Never>
}

extension HapticClient: DependencyKey {
    static let liveValue: HapticClient = .init(
        generateFeedback: { style in
            .fireAndForget {
                HapticUtil.generateFeedback(style: style)
            }
        },
        generateNotificationFeedback: { style in
            .fireAndForget {
                HapticUtil.generateNotificationFeedback(style: style)
            }
        }
    )
    
    static var testValue: HapticClient {
        fatalError("Unimplemented")
    }
}
