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
    case latestUploadedChapter, title
    case createdAt, followedCount, year
    
    enum Order: String {
        case asc, desc
    }
}

func makeMangaSearchRequest(query: String, sortOption: QuerySortOption, order: QuerySortOption.Order, decoder: JSONDecoder) -> Effect<Response<[Manga]>, APIError> {
    var components = URLComponents()
    
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/manga/"
    
    components.queryItems = [
        URLQueryItem(name: "title", value: query),
        URLQueryItem(name: "limit", value: "10"),
        URLQueryItem(name: "offset", value: "0"),
        URLQueryItem(name: "contentRating[]", value: "safe"),
        URLQueryItem(name: "contentRating[]", value: "suggestive"),
        URLQueryItem(name: "contentRating[]", value: "erotica"),
        URLQueryItem(name: "order[\(sortOption)]", value: "\(sortOption == .relevance ? .desc : order)"),
    ]
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
        
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { _ in APIError.downloadError }
        .retry(3)
        .map { data, _ in data }
        .decode(type: Response<[Manga]>.self, decoder: decoder)
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}


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

