//
//  URLSession.swift
//  Smuggler
//
//  Created by mk.pwnz on 31/08/2022.
//

import Foundation
import ComposableArchitecture

extension URLSession {
    func makeRequest<T: Decodable>(to url: URL, decodeResponseAs type: T.Type) -> Effect<T, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
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
