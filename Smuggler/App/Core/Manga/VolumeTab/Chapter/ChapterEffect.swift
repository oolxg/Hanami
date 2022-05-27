//
//  ChapterEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 22/05/2022.
//

import Foundation
import ComposableArchitecture

func downloadPageInfoForChapter(chapterID: UUID) -> Effect<ChapterPagesInfo, APIError> {
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
        .mapError { _ in APIError.downloadError }
        .retry(3)
        .map { data, _ in data }
        .decode(type: ChapterPagesInfo.self, decoder: JSONDecoder())
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}


// Example for URL https://api.mangadex.org/chapter/a33906f0-1928-4758-b6fc-f7f079e2dee2
func downloadChapterInfo(chapterID: UUID, decoder: JSONDecoder) -> Effect<Response<ChapterDetails>, APIError> {
    var components = URLComponents()
    
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/chapter/\(chapterID.uuidString.lowercased())"
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { _ in APIError.downloadError }
        .retry(3)
        .map { data, _ in data }
        .decode(type: Response<ChapterDetails>.self, decoder: decoder)
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}
