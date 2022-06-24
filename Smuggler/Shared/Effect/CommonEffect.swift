//
//  CommonEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 18/06/2022.
//

import Foundation
import ComposableArchitecture

func fetchMangaStatistics(mangaIDs: [UUID]) -> Effect<MangaStatisticsContainer, APIError> {
    guard !mangaIDs.isEmpty else { return .none }
    
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/statistics/manga"
    components.queryItems = []
    
    components.queryItems!.append(
        contentsOf: mangaIDs.map { URLQueryItem(name: "manga[]", value: $0.uuidString.lowercased()) }
    )
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: MangaStatisticsContainer.self, decoder: JSONDecoder())
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
