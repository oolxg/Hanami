//
//  FiltersEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 02/06/2022.
//

import Foundation
import ComposableArchitecture

func downloadTagsList() -> Effect<Response<[Tag]>, AppError> {
    guard let url = URL(string: "https://api.mangadex.org/manga/tag") else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: Response<[Tag]>.self, decoder: JSONDecoder())
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
