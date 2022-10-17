//
//  Settings.swift
//  Hanami
//
//  Created by Oleg on 16/10/2022.
//

import Foundation

enum AutoLockPolicy: Int, Identifiable, CaseIterable, Codable {
    var id: Int { rawValue }
    
    // `never` set to 0 and `instantly` to 1 because of storing `rawValue` in UserDefaults
    // If the value is absent or can't be converted to an integer, 0 will be returned
    case never = 0
    case instantly = 1
    case sec15 = 15
    case min1 = 60
    case min5 = 300
    
    var value: String {
        switch self {
            case .never:
                return "Never"
            case .instantly:
                return "Instantly"
            case .sec15:
                return "15 seconds"
            case .min1:
                return "1 minute"
            case .min5:
                return "5 minutes"
        }
    }
    
    init(rawValue: Int) {
        switch rawValue {
            case 0:
                self = .never
            case 1:
                self = .instantly
            case 15:
                self = .sec15
            case 60:
                self = .min1
            case 300:
                self = .min5
            default:
                self = .never
        }
    }
}
