//
//  URLSession.swift
//  Hanami
//
//  Created by Oleg on 31/08/2022.
//

import Foundation
import ComposableArchitecture

extension URLSession {
    func get<T: Decodable>(url: URL, decodeResponseAs type: T.Type, decoder: JSONDecoder = AppUtil.decoder) -> Effect<T, AppError> {
        var request = URLRequest(url: url)
        
        let userAgent = "Hanami/\(AppUtil.version) (\(DeviceUtil.deviceName); \(DeviceUtil.fullOSName))"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .validateResponseCode()
            .retry(2)
            .map(\.data)
            .decode(type: T.self, decoder: decoder)
            .mapError { err -> AppError in
                if let err = err as? URLError {
                    return AppError.networkError(err)
                } else if let err = err as? DecodingError {
                    return AppError.decodingError(err)
                }
                
                return AppError.unknownError(err)
            }
            .eraseToEffect()
    }
}
