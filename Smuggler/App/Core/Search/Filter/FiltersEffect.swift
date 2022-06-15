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
        .mapError { err in APIError.downloadError(err as URLError) }
        .retry(3)
        .map(\.data)
        .decode(type: Response<[Tag]>.self, decoder: JSONDecoder())
        .mapError { err in APIError.decodingError(err as? DecodingError) }
        .eraseToEffect()
}
