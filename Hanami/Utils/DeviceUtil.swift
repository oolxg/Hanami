//
//  DeviceUtil.swift
//  Hanami
//
//  Created by Oleg on 05/09/2022.
//

import UIKit.UIDevice

enum DeviceUtil {
    static var deviceName: String {
        UIDevice.modelName
    }
    
    static var fullOSName: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }
}
