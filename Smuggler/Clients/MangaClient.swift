//
//  MangaClient.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/07/2022.
//

import Foundation
import ComposableArchitecture

struct MangaClient {
    // swiftlint:disable:next line_length
    let fetchMangaChapters: (_ mangaID: UUID, _ scanlationGroupID: UUID?, _ translatedLang: String?) -> Effect<VolumesContainer, AppError>
    let fetchMangaStatistics: (_ mangaID: UUID) -> Effect<MangaStatisticsContainer, AppError>
    let fetchAllCoverArtsInfForManga: (_ mangaID: UUID) -> Effect<Response<[CoverArtInfo]>, AppError>
    let fetchChapterDetails: (_ chapterID: UUID) -> Effect<Response<ChapterDetails>, AppError>
    let fetchScanlationGroup: (_ scanlationGroupID: UUID) -> Effect<Response<ScanlationGroup>, AppError>
    let fetchPagesInfo: (_ chapterID: UUID) -> Effect<ChapterPagesInfo, AppError>
    let fetchCoverArtInfo: (_ coverArtID: UUID) -> Effect<Response<CoverArtInfo>, AppError>
}

extension MangaClient {
    static var live = MangaClient(
        fetchMangaChapters: { mangaID, scanlationGroupID, translatedLanguage in
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
        },
        fetchMangaStatistics: { mangaID in
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
        },
        fetchAllCoverArtsInfForManga: { mangaID in
            guard let url = URL(
                string: "https://api.mangadex.org/cover?order[volume]=asc&manga[]=\(mangaID.uuidString.lowercased())&limit=100"
            ) else {
                fatalError("Error on creating URL")
            }
            
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
        },
        fetchChapterDetails: { chapterID in
            guard let url = URL(
                string: "https://api.mangadex.org/chapter/\(chapterID.uuidString.lowercased())"
            ) else {
                fatalError("Error on creating URL")
            }
            
            return URLSession.shared.dataTaskPublisher(for: url)
                .validateResponseCode()
                .retry(3)
                .map(\.data)
                .decode(type: Response<ChapterDetails>.self, decoder: AppUtil.decoder)
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
        fetchScanlationGroup: { scanlationGroupID in
            guard let url = URL(
                string: "https://api.mangadex.org/group/\(scanlationGroupID.uuidString.lowercased())"
            ) else {
                fatalError("Error on creating URL")
            }
            
            return URLSession.shared.dataTaskPublisher(for: url)
                .validateResponseCode()
                .retry(3)
                .map(\.data)
                .decode(type: Response<ScanlationGroup>.self, decoder: AppUtil.decoder)
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
        fetchPagesInfo: { chapterID in
            guard let url = URL(
                string: "https://api.mangadex.org/at-home/server/\(chapterID.uuidString.lowercased())"
            ) else {
                fatalError("Error on creating URL")
            }
            
            return URLSession.shared.dataTaskPublisher(for: url)
                .validateResponseCode()
                .retry(3)
                .map(\.data)
                .decode(type: ChapterPagesInfo.self, decoder: JSONDecoder())
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
        fetchCoverArtInfo: { coverArtID in
            guard let url = URL(string: "https://api.mangadex.org/cover/\(coverArtID.uuidString.lowercased())") else {
                return .none
            }
            
            return URLSession.shared.dataTaskPublisher(for: url)
                .validateResponseCode()
                .retry(3)
                .map(\.data)
                .decode(type: Response<CoverArtInfo>.self, decoder: AppUtil.decoder)
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
