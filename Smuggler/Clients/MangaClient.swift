//
//  MangaClient.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/07/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

struct MangaClient {
    // swiftlint:disable line_length
    // MARK: - Networking
    let fetchMangaChapters: (_ mangaID: UUID, _ scanlationGroupID: UUID?, _ translatedLang: String?) -> Effect<VolumesContainer, AppError>
    let fetchMangaStatistics: (_ mangaID: UUID) -> Effect<MangaStatisticsContainer, AppError>
    let fetchAllCoverArtsForManga: (_ mangaID: UUID) -> Effect<Response<[CoverArtInfo]>, AppError>
    let fetchChapterDetails: (_ chapterID: UUID) -> Effect<Response<ChapterDetails>, AppError>
    let fetchScanlationGroup: (_ scanlationGroupID: UUID) -> Effect<Response<ScanlationGroup>, AppError>
    let fetchPagesInfo: (_ chapterID: UUID) -> Effect<ChapterPagesInfo, AppError>
    let fetchCoverArtInfo: (_ coverArtID: UUID) -> Effect<Response<CoverArtInfo>, AppError>
    
    // MARK: - Actions inside App
    let getMangaPaginationPageForReadingChapter: (_ chapterIndex: Double?, _ pages: [[VolumeTabState]]) -> Int?
    let computeNextChapterIndex: (_ currentChapterIndex: Double?, _ chapters: [Chapter]?) -> Int?
    let computePreviousChapterIndex: (_ currentChapterIndex: Double?, _ chapters: [Chapter]?) -> Int?
    let getReadChapterOnPaginationPage: (_ chapterIndex: Double?, IdentifiedArrayOf<VolumeTabState>) -> (volumeID: UUID, chapterID: UUID)?
    
    // MARK: - Manage info for offline reading
    let saveCoverArt: (_ coverArt: UIImage, _ mangaID: UUID, _ cacheClient: CacheClient) -> Effect<Never, Never>
    let retrieveCoverArt: (_ mangaID: UUID, _ cacheClient: CacheClient) -> Effect<Result<UIImage, Error>, Never>
    let saveChapterPage: (_ chapterPage: UIImage, _ chapterPageIndex: Int, _ chapterID: UUID, _ cacheClient: CacheClient) -> Effect<Never, Never>
    let retrieveAllChapterPages: (_ chapterID: UUID, _ pagesCount: Int, _ cacheClient: CacheClient) -> Effect<Result<UIImage, Error>, Never>
    let removeCachedPagesForChapter: (_ chapterID: UUID, _ pagesCount: Int, _ cacheClient: CacheClient) -> Effect<Never, Never>
    let isCoverArtCached: (_ mangaID: UUID, _ cacheClient: CacheClient) -> Bool
    // swiftlint:enable line_length
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
                return .none
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
            guard let url = URL(string: "https://api.mangadex.org/statistics/manga/\(mangaID.uuidString.lowercased())") else {
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
        fetchAllCoverArtsForManga: { mangaID in
            guard let url = URL(string: "https://api.mangadex.org/cover?order[volume]=asc&manga[]=\(mangaID.uuidString.lowercased())&limit=100") else {
                return .none
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
            guard let url = URL(string: "https://api.mangadex.org/chapter/\(chapterID.uuidString.lowercased())") else {
                return .none
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
            guard let url = URL(string: "https://api.mangadex.org/group/\(scanlationGroupID.uuidString.lowercased())") else {
                return .none
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
            guard let url = URL(string: "https://api.mangadex.org/at-home/server/\(chapterID.uuidString.lowercased())") else {
                return .none
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
        },
        getMangaPaginationPageForReadingChapter: { chapterIndex, pages in
            // chapterIndex - index of current reading chapter
            // we find it among all chapters and send user to this page
            guard let chapterIndex = chapterIndex else {
                return nil
            }
            
            for (pageIndex, page) in pages.enumerated() {
                for volumeState in page {
                    if volumeState.chapterStates.first(where: { $0.chapter.chapterIndex == chapterIndex }) != nil {
                        return pageIndex
                    }
                }
            }
            
            return nil
        },
        computeNextChapterIndex: { currentChapterIndex, chapters in
            guard let chapterIndex = chapters?.firstIndex(where: { $0.chapterIndex == currentChapterIndex }) else {
                return nil
            }
            
            return chapterIndex + 1 < chapters!.count ? chapterIndex + 1 : nil
        },
        computePreviousChapterIndex: { currentChapterIndex, chapters in
            // 'currentChapterIndex' - is index(Double) and may not match with index in 'chapters'
            guard let chapterIndex = chapters?.firstIndex(where: { $0.chapterIndex == currentChapterIndex }) else {
                return nil
            }
            
            return chapterIndex > 0 ? chapterIndex - 1 : nil
        },
        getReadChapterOnPaginationPage: { chapterIndex, volumes in
            for volumeStateID in volumes.ids {
                for chapterStateID in volumes[id: volumeStateID]!.chapterStates.ids {
                    let chapterState = volumes[id: volumeStateID]!.chapterStates[id: chapterStateID]!
                    
                    if chapterState.chapter.chapterIndex == chapterIndex {
                        return (volumeID: volumeStateID, chapterID: chapterStateID)
                    }
                }
            }
            
            return nil
        },
        saveCoverArt: { coverArt, mangaID, cacheClient in
            let imageName = "coverArt-\(mangaID.uuidString.lowercased())"
            
            return cacheClient.cacheImage(coverArt, imageName).fireAndForget()
        },
        retrieveCoverArt: { mangaID, cacheClient in
            let imageName = "coverArt-\(mangaID.uuidString.lowercased())"
            
            return cacheClient.retrieveImage(imageName)
        },
        saveChapterPage: { chapterPage, pageIndex, chapterID, cacheClient in
            let imageName = "\(chapterID.uuidString.lowercased())-\(pageIndex)"
            
            return cacheClient.cacheImage(chapterPage, imageName).fireAndForget()
        },
        retrieveAllChapterPages: { chapterID, pagesCount, cacheClient in
            .merge(
                (0..<pagesCount).indices.map { pageIndex in
                    let imageName = "\(chapterID.uuidString.lowercased())-\(pageIndex)"
                    return cacheClient.retrieveImage(imageName)
                }
            )
        },
        removeCachedPagesForChapter: { chapterID, pagesCount, cacheClient in
            .merge(
                (0..<pagesCount).indices.map { pageIndex in
                    let imageName = "\(chapterID.uuidString.lowercased())-\(pageIndex)"
                    return cacheClient.removeImage(imageName)
                }
            )
        },
        isCoverArtCached: { mangaID, cacheClient in
            let imageName = "coverArt-\(mangaID.uuidString.lowercased())"
            
            return cacheClient.isCached(imageName)
        }
    )
}
