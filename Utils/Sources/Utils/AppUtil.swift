//
//  AppUtil.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import Foundation

public enum AppUtil {
    public static var version = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "null"
    }()
    
    public static var build = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "null"
    }()
    
    public static var dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss+00:00"
        fmt.timeZone = .init(identifier: "UTC")
        
        return fmt
    }()
    
    public static var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(AppUtil.dateFormatter)
        return decoder
    }()
    
    public static var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(AppUtil.dateFormatter)
        return encoder
    }()
    
    public enum AppConfiguration {
        case debug
        case testFlight
        case appStore
    }
    
    public static let appConfiguration: AppConfiguration = {
        let isDebug: Bool = {
#if DEBUG
            true
#else
            false
#endif
        }()
        
        if isDebug {
            return .debug
        } else if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .testFlight
        } else {
            return .appStore
        }
    }()
}
