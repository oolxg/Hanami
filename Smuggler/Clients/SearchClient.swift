//
//  SearchClient.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/07/2022.
//

import Foundation
import ComposableArchitecture

struct SearchClient {
    let makeSearchRequest: (SearchState.SearchParams) -> Effect<Response<[Manga]>, AppError>
    let fetchStatistics: (_ mangaIDs: [UUID]) -> Effect<MangaStatisticsContainer, AppError>
    let fetchTags: () -> Effect<Response<[Tag]>, AppError>
}

extension SearchClient {
    static var live = SearchClient(
        makeSearchRequest: { requestParams in
            var components = URLComponents()
            
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/manga/"
            
            components.queryItems = [
                URLQueryItem(name: "title", value: requestParams.searchQuery),
                URLQueryItem(name: "limit", value: "\(requestParams.resultsCount)"),
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "contentRating[]", value: "safe"),
                URLQueryItem(name: "contentRating[]", value: "suggestive"),
                URLQueryItem(name: "contentRating[]", value: "erotica"),
                URLQueryItem(name: "includes[]", value: "cover_art"),
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
                return .none
            }
            
            return URLSession.shared.dataTaskPublisher(for: url)
                .validateResponseCode()
                .retry(3)
                .map(\.data)
                .decode(type: Response<[Manga]>.self, decoder: AppUtil.decoder)
                .mapError { err -> AppError in
                    if let err = err as? URLError {
                        return AppError.downloadError(err)
                    } else if let err = err as? DecodingError {
                        return AppError.decodingError(err)
                    }
                    
                    return AppError.unknownError(err)
                }
                .eraseToEffect()
        },
        fetchStatistics: { mangaIDs in
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
                return .none
            }
            
            return URLSession.shared.dataTaskPublisher(for: url)
                .validateResponseCode()
                .retry(3)
                .map(\.data)
                .decode(type: MangaStatisticsContainer.self, decoder: JSONDecoder())
                .mapError { err -> AppError in
                    if let err = err as? URLError {
                        return AppError.downloadError(err)
                    } else if let err = err as? DecodingError {
                        return AppError.decodingError(err)
                    }
                    
                    return AppError.unknownError(err)
                }
                .eraseToEffect()
        },
        fetchTags: {
            guard let url = URL(string: "https://api.mangadex.org/manga/tag") else {
                return .none
            }
            
            return URLSession.shared.dataTaskPublisher(for: url)
                .validateResponseCode()
                .retry(3)
                .map(\.data)
                .decode(type: Response<[Tag]>.self, decoder: JSONDecoder())
                .mapError { err -> AppError in
                    if let err = err as? URLError {
                        return AppError.downloadError(err)
                    } else if let err = err as? DecodingError {
                        return AppError.decodingError(err)
                    }
                    
                    return AppError.unknownError(err)
                }
                .eraseToEffect()
        }
    )
}
