//
//  HapticClient.swift
//  Smuggler
//
//  Created by tatsuz0u
//  https://github.com/EhPanda-Team/EhPanda/blob/main/EhPanda/App/Tools/Clients/HapticClient.swift
//

import SwiftUI
import ComposableArchitecture

struct HapticClient {
    let generateFeedback: (UIImpactFeedbackGenerator.FeedbackStyle) -> Effect<Never, Never>
    let generateNotificationFeedback: (UINotificationFeedbackGenerator.FeedbackType) -> Effect<Never, Never>
}

extension HapticClient {
    static let live: Self = .init(
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
}
