//
//  AppUtil.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import Foundation
import SwiftUI

enum AppUtil {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "null"
    }
    
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "null"
    }
    
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss+00:00"
        fmt.timeZone = .init(identifier: "UTC")
        
        decoder.dateDecodingStrategy = .formatted(fmt)
        
        return decoder
    }
    
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss+00:00"
        fmt.timeZone = .autoupdatingCurrent
        
        encoder.dateEncodingStrategy = .formatted(fmt)
        return encoder
    }
    
    static var isIpad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
