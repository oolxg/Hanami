//
//  AppUtil.swift
//  Smuggler
//
//  Created by mk.pwnz on 03/07/2022.
//

import Foundation

enum AppUtil {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "null"
    }
    
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "null"
    }
    
    static func dispatchMainSync(execute work: () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }
    
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss+00:00"
        
        decoder.dateDecodingStrategy = .formatted(fmt)
        
        return decoder
    }
    
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss+00:00"
        
        encoder.dateEncodingStrategy = .formatted(fmt)
        return encoder
    }
}
