//
//  URLSession.swift
//  Hanami
//
//  Created by Oleg on 31/08/2022.
//

import Foundation
import struct ComposableArchitecture.EffectPublisher
import Utils

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
    
    func get<T: Decodable>(url: URL, decodeResponseAs _: T.Type, decoder: JSONDecoder = AppUtil.decoder) async throws -> T {
        var request = URLRequest(url: url)
        
        let userAgent = "Hanami/\(AppUtil.version) (\(DeviceUtil.deviceName); \(DeviceUtil.fullOSName))"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (payload, response) = try await URLSession.shared.data(for: request)
        
        guard let response = response as? HTTPURLResponse else {
            throw AppError.networkError(URLError(.unknown))
        }
        
        guard (200..<300).contains(response.statusCode) else {
            throw AppError.networkError(
                URLError(
                    URLError.Code(rawValue: response.statusCode),
                    userInfo: ["url": response.url]
                )
            )
        }
        
        return try decoder.decode(T.self, from: payload)
    }
}
