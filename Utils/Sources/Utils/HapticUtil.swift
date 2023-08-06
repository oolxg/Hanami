//
//  HapticUtil.swift
//  Hanami
//
//  Created by tatsuz0u.
//  https://github.com/EhPanda-Team/EhPanda/blob/main/EhPanda/App/Tools/Utilities/HapticUtil.swift
//

import SwiftUI
import AudioToolbox
import DeviceKit

public enum HapticUtil {
    public static func generateFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard !isLegacyTapticEngine else {
            generateLegacyFeedback()
            return
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    public static func generateNotificationFeedback(style: UINotificationFeedbackGenerator.FeedbackType) {
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
        Device.current == .iPhone6s || Device.current == .iPhone6sPlus
    }()
}
