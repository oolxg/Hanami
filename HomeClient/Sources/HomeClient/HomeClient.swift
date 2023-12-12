//
//  HomeClient.swift
//  Hanami
//
//  Created by Oleg on 12/07/2022.
//

import Foundation
import ComposableArchitecture
import ModelKit
import Utils

extension DependencyValues {
    public var homeClient: HomeClient {
        get { self[HomeClient.self] }
        set { self[HomeClient.self] = newValue }
    }
}


public struct HomeClient {
    private init() { }
    
    public func fetchLatestUpdatesManga() async -> Result<Response<[Manga]>, AppError> {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.mangadex.org"
        components.path = "/manga"
        components.queryItems = [
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "contentRating[]", value: "safe"),
            URLQueryItem(name: "contentRating[]", value: "suggestive"),
            URLQueryItem(name: "contentRating[]", value: "erotica"),
            URLQueryItem(name: "order[latestUploadedChapter]", value: "desc"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "includes[]", value: "author"),
            URLQueryItem(name: "hasAvailableChapters", value: "true")
        ]
        
        guard let url = components.url else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
    }
    
    public func fetchSeasonalMangaList() async -> Result<Response<[Manga]>, AppError> {
        let adminUserListsURL = URL(string: "https://api.mangadex.org/user/d2ae45e0-b5e2-4e7f-a688-17925c2d7d6b/list")
        guard let adminUserListsURL else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        let adminUserMangaListsResult = await URLSession.shared.get(
            url: adminUserListsURL,
            decodeResponseAs: Response<[CustomMangaList]>.self
        )
        
        switch adminUserMangaListsResult {
        case .success(let response):
            let currentSeasonMangaList = getCurrentSeasonMangaList(mangaLists: response.data)
            
            guard let currentSeasonMangaList else { return .failure(.notFound) }
            
            let seasonalMangaIDs = currentSeasonMangaList.relationships
                .filter { $0.type == .manga }
                .map(\.id)

            return await fetchManga(ids: seasonalMangaIDs)
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func fetchCustomMangaList(listID: UUID) async -> Result<Response<CustomMangaList>, AppError> {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.mangadex.org"
        components.path = "/list/\(listID.uuidString.lowercased())"
        components.queryItems = [
            URLQueryItem(name: "includes[]", value: "author"),
            URLQueryItem(name: "includes[]", value: "cover_art")
        ]

        guard let url = components.url else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<CustomMangaList>.self)
    }
    
    public func fetchManga(ids: [UUID]) async -> Result<Response<[Manga]>, AppError> {
        guard !ids.isEmpty else {
            return .failure(.networkError(URLError(.unsupportedURL)))
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.mangadex.org"
        components.path = "/manga"
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(ids.count)"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "includes[]", value: "author"),
            URLQueryItem(name: "hasAvailableChapters", value: "true")
        ]
        
        components.queryItems! += ids.map { URLQueryItem(name: "ids[]", value: $0.uuidString.lowercased()) }
        
        guard let url = components.url else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
    }
    
    public func fetchAwardWinningManga() async -> Result<Response<[Manga]>, AppError> {
        let awardWinningTagID = "0a39b5a1-b235-4886-a747-1d05d216532d"
        
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
            URLQueryItem(name: "includedTags[]", value: awardWinningTagID),
            URLQueryItem(name: "order[rating]", value: "desc"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "includes[]", value: "author"),
            URLQueryItem(name: "hasAvailableChapters", value: "true")
        ]
        
        guard let url = components.url else {
            return .failure(.networkError(URLError(.badURL)))
        }

        return await URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
    }
    
    public func fetchMostFollowedManga() async -> Result<Response<[Manga]>, AppError> {
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
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "hasAvailableChapters", value: "true")
        ]
        
        guard let url = components.url else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<[Manga]>.self)
    }
    
    // MARK: - Private
    private func getCurrentSeasonMangaList(mangaLists: [CustomMangaList]) -> CustomMangaList? {
        var mangaLists = mangaLists.filter { list in
            let name = list.attributes.name
            let pattern = #"^Seasonal: (Winter|Spring|Fall|Summer) \d{4}$"#
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            guard let regex else { return true }
            let range = NSRange(location: 0, length: name.utf16.count)
            let matches = regex.matches(in: name, options: [], range: range)
            
            return !matches.isEmpty
        }
        
        mangaLists.sort { lhs, rhs in
            let lhsYear = lhs.attributes.name.suffix(4)
            let rhsYear = rhs.attributes.name.suffix(4)
            
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
        
        return mangaLists.last
    }
}

extension HomeClient: DependencyKey {
    public static var liveValue = HomeClient()
}
