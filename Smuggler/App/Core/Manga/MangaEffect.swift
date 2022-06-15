//
//  MangaEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

// Example for URL https://api.mangadex.org/manga/9d3d3403-1a87-4737-9803-bc3d99db1424/aggregate
func downloadChaptersForManga(mangaID: UUID, decoder: JSONDecoder) -> Effect<Volumes, APIError> {
    var components = URLComponents()

    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/manga/\(mangaID.uuidString.lowercased())/aggregate"

    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
        
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { _ in APIError.downloadError }
        .retry(3)
        .map(\.data)
        .decode(type: Volumes.self, decoder: decoder)
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
        .map(\.data)
        .decode(type: ChapterPagesInfo.self, decoder: JSONDecoder())
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}


func fetchMangaStatistics(mangaID: UUID) -> Effect<MangaStatisticsContainer, APIError> {
    guard let url = URL(
        string: "https://api.mangadex.org/statistics/manga/\(mangaID.uuidString.lowercased())"
    ) else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { _ in APIError.downloadError }
        .retry(3)
        .map(\.data)
        .decode(type: MangaStatisticsContainer.self, decoder: JSONDecoder())
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}
