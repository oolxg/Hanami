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
                throw APIError.unknownError("Can't decode image: \(url)")
            }
            
            return image
        }
        .mapError { err -> APIError in
            if err is URLError {
                return APIError.downloadError(err as! URLError)
            } else if err is DecodingError {
                return APIError.decodingError(err as! DecodingError)
            }
            
            return APIError.unknownError(err.localizedDescription)
        }
        .eraseToEffect()
}
