//
//  HomeEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation
import ComposableArchitecture

func downloadMangaList(decoder: JSONDecoder) -> Effect<Response<[Manga]>, APIError> {
    let today = Calendar.current.startOfDay(for: Date(timeIntervalSinceNow: -86400))
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/manga"
    components.queryItems = [
        URLQueryItem(name: "limit", value: "20"),
        URLQueryItem(name: "includedTagsMode", value: "AND"),
        URLQueryItem(name: "excludedTagsMode", value: "OR"),
        URLQueryItem(name: "contentRating[]", value: "safe"),
        URLQueryItem(name: "contentRating[]", value: "suggestive"),
        URLQueryItem(name: "contentRating[]", value: "erotica"),
        URLQueryItem(name: "updatedAtSince", value: fmt.string(from: today)),
        URLQueryItem(name: "order[latestUploadedChapter]", value: "desc"),
        URLQueryItem(name: "order[relevance]", value: "desc")
    ]

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
