//
//  FiltersEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 02/06/2022.
//

import Foundation
import ComposableArchitecture

func downloadTagsList() -> Effect<Response<[Tag]>, APIError> {
    guard let url = URL(string: "https://api.mangadex.org/manga/tag") else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: Response<[Tag]>.self, decoder: JSONDecoder())
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
