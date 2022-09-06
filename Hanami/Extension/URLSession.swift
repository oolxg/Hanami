//
//  URLSession.swift
//  Hanami
//
//  Created by Oleg on 31/08/2022.
//

import Foundation
import ComposableArchitecture

extension URLSession {
    func get<T: Decodable>(url: URL, decodeResponseAs type: T.Type) -> Effect<T, AppError> {
        var request = URLRequest(url: url)
        
        request.setValue("Hanami/\(AppUtil.version) \(DeviceUtil.deviceName)", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .validateResponseCode()
            .retry(3)
            .map(\.data)
            .decode(type: T.self, decoder: AppUtil.decoder)
            .mapError { err -> AppError in
                if let err = err as? URLError {
                    return AppError.downloadError(err)
                } else if let err = err as? DecodingError {
                    return AppError.decodingError(err)
                }
                
                return AppError.unknownError(err)
            }
            .eraseToEffect()
    }
}
