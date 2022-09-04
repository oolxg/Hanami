//
//  HomeClient.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/07/2022.
//

import Foundation
import ComposableArchitecture

struct HomeClient {
    let fetchLastUpdates: () -> Effect<Response<[Manga]>, AppError>
    let fetchSeasonalTitlesList: () -> Effect<Response<CustomMangaList>, AppError>
    let fetchMangaByIDs: ([UUID]) -> Effect<Response<[Manga]>, AppError>
    let fetchAwardWinningManga: () -> Effect<Response<[Manga]>, AppError>
    let fetchMostFollowedManga: () -> Effect<Response<[Manga]>, AppError>
    let fetchHighestRatingManga: () -> Effect<Response<[Manga]>, AppError>
    let fetchRecentlyAddedManga: () -> Effect<Response<[Manga]>, AppError>
    let fetchStatistics: (_ mangaIDs: [UUID]) -> Effect<MangaStatisticsContainer, AppError>
}

extension HomeClient {
    static var live = HomeClient(
        fetchLastUpdates: {
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
                URLQueryItem(name: "order[latestUploadedChapter]", value: "desc"),
                URLQueryItem(name: "includes[]", value: "cover_art"),
                URLQueryItem(name: "includes[]", value: "author")
            ]
            
            guard let url = components.url else {
                return .none
            }
                      
            return URLSession.shared.makeRequest(to: url, decodeResponseAs: Response<[Manga]>.self)
        },
        fetchSeasonalTitlesList: {
            // admin user has 'Seasonal' manga list
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/list/7df1dabc-b1c5-4e8e-a757-de5a2a3d37e9"
            components.queryItems = [
                URLQueryItem(name: "includes[]", value: "author"),
                URLQueryItem(name: "includes[]", value: "cover_art"),
                URLQueryItem(name: "includes[]", value: "user")
            ]

            guard let adminUserListsURL = components.url else {
                return .none
            }
            
            return URLSession.shared.makeRequest(
                to: adminUserListsURL,
                decodeResponseAs: Response<CustomMangaList>.self
            )
        },
        fetchMangaByIDs: { mangaIDs in
            guard !mangaIDs.isEmpty else { return .none }
            
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/manga"
            components.queryItems = [
                URLQueryItem(name: "limit", value: "\(mangaIDs.count)"),
                URLQueryItem(name: "includes[]", value: "cover_art"),
                URLQueryItem(name: "includes[]", value: "author")
            ]
            
            components.queryItems!.append(
                contentsOf: mangaIDs.map { URLQueryItem(name: "ids[]", value: $0.uuidString.lowercased()) }
            )
            
            guard let url = components.url else {
                return .none
            }
                
            return URLSession.shared.makeRequest(to: url, decodeResponseAs: Response<[Manga]>.self)
        },
        fetchAwardWinningManga: {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/manga"
            components.queryItems = [
                URLQueryItem(name: "limit", value: "25"),
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "contentRating[]", value: "safe"),
                URLQueryItem(name: "contentRating[]", value: "suggestive"),
                URLQueryItem(name: "contentRating[]", value: "erotica"),
                // award-winning tag UUID
                URLQueryItem(name: "includedTags[]", value: "0a39b5a1-b235-4886-a747-1d05d216532d"),
                URLQueryItem(name: "order[rating]", value: "desc"),
                URLQueryItem(name: "includes[]", value: "cover_art"),
                URLQueryItem(name: "includes[]", value: "author")
            ]
            
            guard let url = components.url else {
                return .none
            }

            return URLSession.shared.makeRequest(to: url, decodeResponseAs: Response<[Manga]>.self)
        },
        fetchMostFollowedManga: {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/manga"
            components.queryItems = [
                URLQueryItem(name: "limit", value: "25"),
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "contentRating[]", value: "safe"),
                URLQueryItem(name: "contentRating[]", value: "suggestive"),
                URLQueryItem(name: "contentRating[]", value: "erotica"),
                URLQueryItem(name: "order[followedCount]", value: "desc"),
                URLQueryItem(name: "includes[]", value: "author"),
                URLQueryItem(name: "includes[]", value: "cover_art")
            ]
            
            guard let url = components.url else {
                return .none
            }
            
            return URLSession.shared.makeRequest(to: url, decodeResponseAs: Response<[Manga]>.self)
        },
        fetchHighestRatingManga: {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/manga"
            components.queryItems = [
                URLQueryItem(name: "limit", value: "25"),
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "contentRating[]", value: "safe"),
                URLQueryItem(name: "contentRating[]", value: "suggestive"),
                URLQueryItem(name: "contentRating[]", value: "erotica"),
                URLQueryItem(name: "order[rating]", value: "desc"),
                URLQueryItem(name: "includes[]", value: "author"),
                URLQueryItem(name: "includes[]", value: "cover_art")
            ]
            
            guard let url = components.url else {
                return .none
            }
            
            return URLSession.shared.makeRequest(to: url, decodeResponseAs: Response<[Manga]>.self)
        },
        fetchRecentlyAddedManga: {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/manga"
            components.queryItems = [
                URLQueryItem(name: "limit", value: "25"),
                URLQueryItem(name: "offset", value: "0"),
                URLQueryItem(name: "contentRating[]", value: "safe"),
                URLQueryItem(name: "contentRating[]", value: "suggestive"),
                URLQueryItem(name: "contentRating[]", value: "erotica"),
                URLQueryItem(name: "order[createdAt]", value: "desc"),
                URLQueryItem(name: "includes[]", value: "author"),
                URLQueryItem(name: "includes[]", value: "cover_art")
            ]
            
            guard let url = components.url else {
                return .none
            }
            
            return URLSession.shared.makeRequest(to: url, decodeResponseAs: Response<[Manga]>.self)
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
            
            return URLSession.shared.makeRequest(to: url, decodeResponseAs: MangaStatisticsContainer.self)
        }
    )
}
