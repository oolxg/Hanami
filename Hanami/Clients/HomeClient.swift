//
//  HomeClient.swift
//  Hanami
//
//  Created by Oleg on 12/07/2022.
//

import Foundation
import ComposableArchitecture

struct HomeClient {
    let fetchLastUpdates: () -> Effect<Response<[Manga]>, AppError>
    let fetchAllSeasonalTitlesLists: () -> Effect<Response<[CustomMangaList]>, AppError>
    let getCurrentSeasonTitlesListID: (_ mangaLists: [CustomMangaList]) -> (id: UUID, name: String)
    let fetchSeasonalTitlesList: (_ seasonalTitlesListID: UUID) -> Effect<Response<CustomMangaList>, AppError>
    let fetchMangaByIDs: ([UUID]) -> Effect<Response<[Manga]>, AppError>
    let fetchAwardWinningManga: () -> Effect<Response<[Manga]>, AppError>
    let fetchMostFollowedManga: () -> Effect<Response<[Manga]>, AppError>
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
                URLQueryItem(name: "limit", value: "25"),
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
                      
            return URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
        },
        fetchAllSeasonalTitlesLists: {
            // admin user URL
            guard let url = URL(string: "https://api.mangadex.org/user/d2ae45e0-b5e2-4e7f-a688-17925c2d7d6b/list") else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<[CustomMangaList]>.self)
        },
        getCurrentSeasonTitlesListID: { mangaLists in
            let sorted = mangaLists.sorted { lhs, rhs in
                let lhsYear = String(lhs.attributes.name.suffix(4))
                let rhsYear = String(rhs.attributes.name.suffix(4))
                
                if lhsYear != rhsYear {
                    return lhsYear < rhsYear
                }
                
                let priority = ["Winter", "Spring", "Summer", "Fall"]
                
                let lhsSeason = lhs.attributes.name
                    .replacingOccurrences(of: "Seasonal: ", with: "")
                    .replacingOccurrences(of: " \(lhsYear)", with: "")
                
                let rhsSeason = rhs.attributes.name
                    .replacingOccurrences(of: "Seasonal: ", with: "")
                    .replacingOccurrences(of: " \(rhsYear)", with: "")
                
                let lhsPriority = priority.firstIndex(of: lhsSeason) ?? -1
                let rhsPriority = priority.firstIndex(of: rhsSeason) ?? -1
                
                return lhsPriority < rhsPriority
            }
            
            return (id: sorted.last!.id, name: sorted.last!.attributes.name)
        },
        fetchSeasonalTitlesList: { seasonalTitlesListID in
            // admin user has 'Seasonal' manga list
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/list/\(seasonalTitlesListID.uuidString.lowercased())"
            components.queryItems = [
                URLQueryItem(name: "includes[]", value: "author"),
                URLQueryItem(name: "includes[]", value: "cover_art"),
                URLQueryItem(name: "includes[]", value: "user")
            ]

            guard let adminUserListsURL = components.url else {
                return .none
            }
            
            return URLSession.shared.get(
                url: adminUserListsURL,
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
                
            return URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
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

            return URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
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
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
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
            
            return URLSession.shared.get(url: url, decodeResponseAs: MangaStatisticsContainer.self)
        }
    )
}
