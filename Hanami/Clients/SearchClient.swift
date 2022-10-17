//
//  SearchClient.swift
//  Hanami
//
//  Created by Oleg on 12/07/2022.
//

import Foundation
import ComposableArchitecture

extension DependencyValues {
    var searchClient: SearchClient {
        get { self[SearchClient.self] }
        set { self[SearchClient.self] = newValue }
    }
}

struct SearchClient {
    let makeSearchRequest: (SearchFeature.SearchParams) -> Effect<Response<[Manga]>, AppError>
    let fetchStatistics: (_ mangaIDs: [UUID]) -> Effect<MangaStatisticsContainer, AppError>
    let fetchTags: () -> Effect<Response<[Tag]>, AppError>
}

extension SearchClient: DependencyKey {
    static let liveValue = SearchClient(
        makeSearchRequest: { requestParams in
            var components = URLComponents()
            
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/manga"
            
            components.queryItems = [
                URLQueryItem(name: "title", value: requestParams.searchQuery),
                URLQueryItem(name: "limit", value: "\(requestParams.resultsCount)"),
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "contentRating[]", value: "safe"),
                URLQueryItem(name: "contentRating[]", value: "suggestive"),
                URLQueryItem(name: "contentRating[]", value: "erotica"),
                URLQueryItem(name: "includes[]", value: "cover_art"),
                URLQueryItem(name: "includes[]", value: "author"),
                URLQueryItem(name: "order[\(requestParams.sortOption)]", value: "\(requestParams.sortOptionOrder)")
            ]
            
            components.queryItems!.append(
                contentsOf: requestParams.tags
                    .filter { $0.state == .banned }
                    .map { URLQueryItem(name: "excludedTags[]", value: $0.id.uuidString.lowercased()) }
            )
            
            components.queryItems!.append(
                contentsOf: requestParams.tags
                    .filter { $0.state == .selected }
                    .map { URLQueryItem(name: "includedTags[]", value: $0.id.uuidString.lowercased()) }
            )
            
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
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
        },
        fetchStatistics: { mangaIDs in
            guard !mangaIDs.isEmpty else { return .none }
            
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/statistics/manga"
            components.queryItems = mangaIDs.map {
                URLQueryItem(name: "manga[]", value: $0.uuidString.lowercased())
            }
            
            guard let url = components.url else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: MangaStatisticsContainer.self)
        },
        fetchTags: {
            guard let url = URL(string: "https://api.mangadex.org/manga/tag") else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<[Tag]>.self)
        }
    )
}
