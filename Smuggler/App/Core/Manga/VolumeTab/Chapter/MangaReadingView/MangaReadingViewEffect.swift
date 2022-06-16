//
//  MangaReadingViewEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import Foundation
import ComposableArchitecture

func fetchPageInfoForChapter(chapterID: UUID) -> Effect<ChapterPagesInfo, APIError> {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/at-home/server/\(chapterID.uuidString.lowercased())"
    components.queryItems = [
        URLQueryItem(name: "forcePort443", value: "\(false)")
    ]
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { err in APIError.downloadError(err as URLError) }
        .retry(3)
        .map(\.data)
        .decode(type: ChapterPagesInfo.self, decoder: JSONDecoder())
        .mapError { err in APIError.decodingError(err as? DecodingError) }
        .eraseToEffect()
}
