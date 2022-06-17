//
//  SearchEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 29/05/2022.
//

import Foundation
import ComposableArchitecture

enum QuerySortOption: String {
    case relevance
    // can be desc and asc
    case latestUploadedChapter, title, rating
    case createdAt, followedCount, year
    
    enum Order: String {
        case asc, desc
    }
}

func makeMangaSearchRequest(requestParams: SearchState.RequestParams, decoder: JSONDecoder) -> Effect<Response<[Manga]>, APIError> {
    var components = URLComponents()
    
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/manga/"
    
    components.queryItems = [
        URLQueryItem(name: "title", value: requestParams.searchQuery),
        URLQueryItem(name: "limit", value: "10"),
        URLQueryItem(name: "offset", value: "0"),
        URLQueryItem(name: "contentRating[]", value: "safe"),
        URLQueryItem(name: "contentRating[]", value: "suggestive"),
        URLQueryItem(name: "contentRating[]", value: "erotica"),
        URLQueryItem(name: "order[\(requestParams.sortOption)]", value: "\(requestParams.sortOptionOrder)")
    ]
    
    for tag in requestParams.tags {
        if tag.state == .banned {
            components.queryItems?.append(
                URLQueryItem(name: "excludedTags[]", value: tag.id.uuidString.lowercased())
            )
        } else if tag.state == .selected {
            components.queryItems?.append(
                URLQueryItem(name: "includedTags[]", value: tag.id.uuidString.lowercased())
            )
        }
    }
    
    components.queryItems?.append(
        contentsOf: requestParams.publicationDemographic.filter { $0.state == .selected }
            .map { URLQueryItem(name: "publicationDemographic[]", value: $0.name) }
    )
    
    components.queryItems?.append(
        contentsOf: requestParams.contentRatings.filter { $0.state == .selected }
            .map { URLQueryItem(name: "contentRating[]", value: $0.name) }
    )
    
    components.queryItems?.append(
        contentsOf: requestParams.mangaStatuses.filter { $0.state == .selected }
            .map { URLQueryItem(name: "status[]", value: $0.name) }
    )
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { err in APIError.downloadError(err as URLError) }
        .retry(3)
        .map(\.data)
        .decode(type: Response<[Manga]>.self, decoder: decoder)
        .mapError { err in APIError.decodingError(err as? DecodingError) }
        .eraseToEffect()
}
