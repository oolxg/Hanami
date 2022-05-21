//
//  MangaEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

func downloadChaptersForManga(mangaID: UUID, chaptersCount: Int, offset: Int, decoder: JSONDecoder) -> Effect<Response<[Chapter]>, APIError> {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/chapter"
    components.queryItems = [
        URLQueryItem(name: "manga", value: "\(mangaID.uuidString.lowercased())"),
        URLQueryItem(name: "limit", value: "\(chaptersCount)"),
        URLQueryItem(name: "offset", value: "\(offset)")
    ]
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
        
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { _ in APIError.downloadError }
        .retry(3)
        .map { data, _ in data }
        .decode(type: Response<[Chapter]>.self, decoder: decoder)
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}

func downloadPageInfoForChapter(chapterID: UUID, forcePort443: Bool) -> Effect<ChapterPagesInfo, APIError> {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/at-home/server/\(chapterID.uuidString.lowercased())"
    components.queryItems = [
        URLQueryItem(name: "forcePort443", value: "\(forcePort443)")
    ]
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { _ in APIError.downloadError }
        .retry(3)
//        .map { data, _ in data }
        .map { data, response in
            let resp = response as? HTTPURLResponse
            
            print("chapter", resp?.statusCode)
            
            return data
        }
        .decode(type: ChapterPagesInfo.self, decoder: JSONDecoder())
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}
