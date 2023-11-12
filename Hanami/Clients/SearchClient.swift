//
//  SearchClient.swift
//  Hanami
//
//  Created by Oleg on 12/07/2022.
//

import Foundation
import Dependencies
import ModelKit
import Utils

public extension DependencyValues {
    var searchClient: SearchClient {
        get { self[SearchClient.self] }
        set { self[SearchClient.self] = newValue }
    }
}

public struct SearchClient {
    public func makeSearchRequest(with searchParams: SearchParams) async throws -> Response<[Manga]> {
        var components = URLComponents()
        
        components.scheme = "https"
        components.host = "api.mangadex.org"
        components.path = "/manga"
        
        components.queryItems = [
            URLQueryItem(name: "title", value: searchParams.searchQuery),
            URLQueryItem(name: "limit", value: "\(searchParams.resultsCount)"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "contentRating[]", value: "safe"),
            URLQueryItem(name: "contentRating[]", value: "suggestive"),
            URLQueryItem(name: "contentRating[]", value: "erotica"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "includes[]", value: "author"),
            URLQueryItem(name: "order[\(searchParams.sortOption)]", value: "\(searchParams.sortOptionOrder)")
        ]
        
        components.queryItems! += searchParams.tags.filter { $0.state == .banned }
            .map { URLQueryItem(name: "excludedTags[]", value: $0.id.uuidString.lowercased()) }
        
        components.queryItems! += searchParams.tags.filter { $0.state == .selected }
            .map { URLQueryItem(name: "includedTags[]", value: $0.id.uuidString.lowercased()) }
        
        components.queryItems! += searchParams.publicationDemographic.filter { $0.state == .selected }
            .map { URLQueryItem(name: "publicationDemographic[]", value: $0.name) }
        
        components.queryItems! += searchParams.contentRatings.filter { $0.state == .selected }
            .map { URLQueryItem(name: "contentRating[]", value: $0.name) }
        
        components.queryItems! += searchParams.mangaStatuses.filter { $0.state == .selected }
            .map { URLQueryItem(name: "status[]", value: $0.name) }
        
        guard let url = components.url else {
            throw AppError.networkError(URLError(.badURL))
        }
        
        return try await URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
    }
    
    public func fetchTags() async throws -> Response<[Tag]> {
        let url = URL(string: "https://api.mangadex.org/manga/tag")!
        
        return try await URLSession.shared.get(url: url, decodeResponseAs: Response<[Tag]>.self)
    }
}

extension SearchClient: DependencyKey {
    public static let liveValue = SearchClient()
}
