//
//  MangaEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

// Example for URL https://api.mangadex.org/manga/aa6c76f7-5f5f-46b6-a800-911145f81b9b/aggregate?translatedLanguage[]=en&groups[]=063cf1b0-9e25-495b-b234-296579a34496
func fetchChaptersForManga(mangaID: UUID, scanlationGroupID: UUID?, translatedLanguage: String?) -> Effect<VolumesContainer, AppError> {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/manga/\(mangaID.uuidString.lowercased())/aggregate"
    
    components.queryItems = []
    
    if let scanlationGroupID = scanlationGroupID {
        components.queryItems!.append(
            URLQueryItem(name: "groups[]", value: scanlationGroupID.uuidString.lowercased())
        )
    }
    
    if let translatedLanguage = translatedLanguage {
        components.queryItems!.append(
            URLQueryItem(name: "translatedLanguage[]", value: translatedLanguage)
        )
    }
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
        
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: VolumesContainer.self, decoder: AppUtil.decoder)
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


func fetchMangaStatistics(mangaID: UUID) -> Effect<MangaStatisticsContainer, AppError> {
    guard let url = URL(
        string: "https://api.mangadex.org/statistics/manga/\(mangaID.uuidString.lowercased())"
    ) else {
        fatalError("Error on creating URL")
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
}

func fetchAllCoverArtsInfoForManga(mangaID: UUID) -> Effect<Response<[CoverArtInfo]>, AppError> {
    guard let url = URL(
        string: "https://api.mangadex.org/cover?order[volume]=asc&manga[]=\(mangaID.uuidString.lowercased())&limit=100"
    ) else {
        fatalError("Error on creating URL")
    }
    
    print(url)
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: Response<[CoverArtInfo]>.self, decoder: AppUtil.decoder)
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
