//
//  URLSession.swift
//  Hanami
//
//  Created by Oleg on 31/08/2022.
//

import Foundation
import struct ComposableArchitecture.EffectPublisher

extension URLSession {
    func get<T: Decodable>(url: URL, decodeResponseAs _: T.Type, decoder: JSONDecoder = AppUtil.decoder) -> EffectPublisher<T, AppError> {
        var request = URLRequest(url: url)
        
        let userAgent = "Hanami/\(AppUtil.version) (\(DeviceUtil.deviceName); \(DeviceUtil.fullOSName))"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .validateResponseCode()
            .retry(2)
            .map(\.data)
            .decode(type: T.self, decoder: decoder)
            .mapError { err -> AppError in
                if let err = err as? URLError {
                    return .networkError(err)
                } else if let err = err as? DecodingError {
                    return .decodingError(err)
                }
                
                return .unknownError(err)
            }
            .eraseToEffect()
    }
}
