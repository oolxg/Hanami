//
//  Settings.swift
//  Hanami
//
//  Created by Oleg on 16/10/2022.
//

import Foundation

public enum AutoLockPolicy: Int {
    // `never` set to 0 and `instantly` to 1 because of storing `rawValue` in UserDefaults
    // If the value is absent or can't be converted to an integer, 0 will be returned
    case never = 0
    case instantly = 1
    case sec15 = 15
    case min1 = 60
    case min5 = 300
    
    public var value: String {
        switch self {
        case .never:
            return "Never"
        case .instantly:
            return "Instantly"
        case .sec15:
            return "After 15 sec"
        case .min1:
            return "After 1 min"
        case .min5:
            return "After 5 min"
        }
    }
    
    public init(rawValue: Int) {
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
    
    // autolock delay in seconds
    public var autolockDelay: Int {
        switch self {
        case .never:
            return -1
        case .instantly:
            return 0
        case .sec15:
            return 15
        case .min1:
            return 60
        case .min5:
            return 5 * 60
        }
    }
}

extension AutoLockPolicy: Identifiable {
    public var id: Int { rawValue }
}

extension AutoLockPolicy: CaseIterable { }

extension AutoLockPolicy: Codable { }
