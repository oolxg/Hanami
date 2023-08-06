//
//  DeviceUtil.swift
//  Hanami
//
//  Created by Oleg on 05/09/2022.
//

import DeviceKit
import UIKit

public enum DeviceUtil {
    public static var deviceName: String {
        Device.current.name ?? "unkown"
    }
    
    public static var fullOSName: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }
    
    public static func disableScreenAutoLock() {
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    public static func enableScreenAutoLock() {
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    public static var isIpad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    public static var deviceScreenSize: CGRect {
        UIScreen.main.bounds
    }
    
    public static var hasTopNotch = {
        let scenes = UIApplication.shared.connectedScenes
        guard let windowScene = scenes.first as? UIWindowScene else { return false }
        
        if windowScene.windows.isEmpty { return false }          // Should never occur, but…
        let top = windowScene.windows[0].safeAreaInsets.top
        return top > 20
    }()
}
