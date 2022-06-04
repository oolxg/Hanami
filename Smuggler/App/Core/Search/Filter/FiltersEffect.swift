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
        .mapError { _ in APIError.downloadError }
        .retry(3)
        .map { data, _ in data }
        .decode(type: Response<[Tag]>.self, decoder: JSONDecoder())
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}
