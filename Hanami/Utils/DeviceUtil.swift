//
//  DeviceUtil.swift
//  Hanami
//
//  Created by Oleg on 05/09/2022.
//

import Foundation
import UIKit.UIDevice

enum DeviceUtil {
    static var deviceName: String {
        UIDevice.current.name
    }
}
