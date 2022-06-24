//
//  SystemFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 17/05/2022.
//

import Foundation
import SwiftUI
import ComposableArchitecture

func loadImage(url: URL?) -> Effect<UIImage, APIError> {
    guard let url = url else {
        return .none
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .tryMap { data, _ in
            guard let image = UIImage(data: data) else {
                // swiftlint:disable:next force_cast
                throw APIError.unknownError(URLError.badServerResponse as! Error)
            }
            
            return image
        }
        .mapError { err -> APIError in
            if let err = err as? URLError {
                return APIError.downloadError(err)
            } else if let err = err as? DecodingError {
                return APIError.decodingError(err)
            }
            
            return APIError.unknownError(err)
        }
        .eraseToEffect()
}
