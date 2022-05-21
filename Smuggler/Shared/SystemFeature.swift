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
        .mapError { _ in APIError.downloadError }
        .retry(3)
        .tryMap { data, _ in
            guard let image = UIImage(data: data) else {
                throw APIError.decodingError
            }
            
            return image
        }
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}
