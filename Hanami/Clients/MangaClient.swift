//
//  MangaClient.swift
//  Hanami
//
//  Created by Oleg on 12/07/2022.
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
    let getMangaPageForReadingChapter: (_ chapterIndex: Double?, _ pages: [[VolumeTabState]]) -> Int?
    let computeNextChapterIndex: (_ currentChapterIndex: Double?, _ chapters: [Chapter]?) -> Int?
    let computeChapterIndex: (_ chapterIndexToFind: Double?, _ chapters: [Chapter]?) -> Int?
    let computePreviousChapterIndex: (_ currentChapterIndex: Double?, _ chapters: [Chapter]?) -> Int?
    let findDidReadChapterOnMangaPage: (_ chapterIndex: Double?, IdentifiedArrayOf<VolumeTabState>) -> (volumeID: UUID, chapterID: UUID)?
    
    let saveCoverArt: (_ coverArt: UIImage, _ mangaID: UUID, _ cacheClient: CacheClient) -> Effect<Never, Never>
    let saveChapterPage: (_ chapterPage: UIImage, _ chapterPageIndex: Int, _ chapterID: UUID, _ cacheClient: CacheClient) -> Effect<Never, Never>
    let removeCachedPagesForChapter: (_ chapterID: UUID, _ pagesCount: Int, _ cacheClient: CacheClient) -> Effect<Never, Never>
    let isCoverArtCached: (_ mangaID: UUID, _ cacheClient: CacheClient) -> Bool
    let isChapterCacheValid: (_ chapterID: UUID, _ pagesCount: Int, _ cacheClient: CacheClient) -> Bool
    let getPathsForCachedChapterPages: (_ chapterID: UUID, _ pagesCount: Int, _ cacheClient: CacheClient) -> [URL?]
    let getCoverArtPath: (_ mangaID: UUID, _ cacheClient: CacheClient) -> URL?
    // swiftlint:enable line_length
}

extension MangaClient {
    // MARK: - Manage info for offline reading
    private static func getCoverArtName(mangaID: UUID) -> String {
        "coverArt-\(mangaID.uuidString.lowercased())"
    }
    private static func getChapterPageName(chapterID: UUID, pageIndex: Int) -> String {
        "\(chapterID.uuidString.lowercased())-\(pageIndex)"
    }
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
            
            return URLSession.shared.get(url: url, decodeResponseAs: VolumesContainer.self)
        },
        fetchMangaStatistics: { mangaID in
            guard let url = URL(string: "https://api.mangadex.org/statistics/manga/\(mangaID.uuidString.lowercased())") else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: MangaStatisticsContainer.self)
        },
        fetchAllCoverArtsForManga: { mangaID in
            guard let url = URL(string: "https://api.mangadex.org/cover?order[volume]=asc&manga[]=\(mangaID.uuidString.lowercased())&limit=100") else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<[CoverArtInfo]>.self)
        },
        fetchChapterDetails: { chapterID in
            guard let url = URL(string: "https://api.mangadex.org/chapter/\(chapterID.uuidString.lowercased())?includes[]=scanlation_group") else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<ChapterDetails>.self)
        },
        fetchScanlationGroup: { scanlationGroupID in
            guard let url = URL(string: "https://api.mangadex.org/group/\(scanlationGroupID.uuidString.lowercased())") else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<ScanlationGroup>.self)
        },
        fetchPagesInfo: { chapterID in
            guard let url = URL(string: "https://api.mangadex.org/at-home/server/\(chapterID.uuidString.lowercased())") else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: ChapterPagesInfo.self)
        },
        fetchCoverArtInfo: { coverArtID in
            guard let url = URL(string: "https://api.mangadex.org/cover/\(coverArtID.uuidString.lowercased())") else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<CoverArtInfo>.self)
        },
        getMangaPageForReadingChapter: { chapterIndex, pages in
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
        computeChapterIndex: { chapterIndex, chapters in
            guard let chapterIndex = chapters?.firstIndex(where: { $0.chapterIndex == chapterIndex }) else {
                return nil
            }
            
            return chapterIndex >= 0 && chapterIndex < chapters!.count ? chapterIndex : nil
        },
        computePreviousChapterIndex: { currentChapterIndex, chapters in
            // 'currentChapterIndex' - is index(Double) and may not match with index in 'chapters'
            guard let chapterIndex = chapters?.firstIndex(where: { $0.chapterIndex == currentChapterIndex }) else {
                return nil
            }
            
            return chapterIndex > 0 ? chapterIndex - 1 : nil
        },
        findDidReadChapterOnMangaPage: { chapterIndex, volumes in
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
            let imageName = getCoverArtName(mangaID: mangaID)
            
            return cacheClient.cacheImage(coverArt, imageName).fireAndForget()
        },
        saveChapterPage: { chapterPage, pageIndex, chapterID, cacheClient in
            let imageName = getChapterPageName(chapterID: chapterID, pageIndex: pageIndex)
            
            return cacheClient.cacheImage(chapterPage, imageName).fireAndForget()
        },
        removeCachedPagesForChapter: { chapterID, pagesCount, cacheClient in
            .merge(
                (0..<pagesCount).indices.map { pageIndex in
                    let imageName = getChapterPageName(chapterID: chapterID, pageIndex: pageIndex)
                    return cacheClient.removeImage(imageName)
                }
            )
            .fireAndForget()
        },
        isCoverArtCached: { mangaID, cacheClient in
            let imageName = getCoverArtName(mangaID: mangaID)
            
            return cacheClient.isCached(imageName)
        },
        isChapterCacheValid: { chapterID, pagesCount, cacheClient in
            // checks whether all pages from chapter cached
            (0..<pagesCount).indices.map { pageIndex in
                let imageName = getChapterPageName(chapterID: chapterID, pageIndex: pageIndex)
                return cacheClient.isCached(imageName)
            }
            .allSatisfy { $0 }
        },
        getPathsForCachedChapterPages: { chapterID, pagesCount, cacheClient in
            (0..<pagesCount).indices.map { pageIndex in
                cacheClient.pathForImage(getChapterPageName(chapterID: chapterID, pageIndex: pageIndex))
            }
        },
        getCoverArtPath: { mangaID, cacheClient in
            cacheClient.pathForImage(getCoverArtName(mangaID: mangaID))
        }
    )
}
