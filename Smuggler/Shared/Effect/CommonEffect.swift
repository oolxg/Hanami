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
        .mapError { err in APIError.downloadError(err as URLError) }
        .retry(3)
        .map(\.data)
        .decode(type: MangaStatisticsContainer.self, decoder: JSONDecoder())
        .mapError { err in APIError.decodingError(err as? DecodingError) }
        .eraseToEffect()
}
