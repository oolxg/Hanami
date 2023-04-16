//
//  HapticUtil.swift
//  Hanami
//
//  Created by tatsuz0u.
//  https://github.com/EhPanda-Team/EhPanda/blob/main/EhPanda/App/Tools/Utilities/HapticUtil.swift
//

import SwiftUI
import AudioToolbox

enum HapticUtil {
    static func generateFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard !isLegacyTapticEngine else {
            generateLegacyFeedback()
            return
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    static func generateNotificationFeedback(style: UINotificationFeedbackGenerator.FeedbackType) {
        guard !isLegacyTapticEngine else {
            generateLegacyFeedback()
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(style)
    }
    
    private static func generateLegacyFeedback() {
        AudioServicesPlaySystemSound(1519)
        AudioServicesPlaySystemSound(1520)
        AudioServicesPlaySystemSound(1521)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    private static let isLegacyTapticEngine: Bool = {
        ["iPhone8,1", "iPhone8,2"].contains(UIDevice.identifier)
    }()
}
