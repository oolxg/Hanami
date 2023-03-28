//
//  MangaClient.swift
//  Hanami
//
//  Created by Oleg on 12/07/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIImage

extension DependencyValues {
    var mangaClient: MangaClient {
        get { self[MangaClient.self] }
        set { self[MangaClient.self] = newValue }
    }
}

struct MangaClient {
    // swiftlint:disable line_length
    // MARK: - Networking
    /// Fetch from MangaDex API aggregated manga chapters
    ///
    /// - Parameter mangaID: Manga's `UUID`, whose chapter are need to be fetched
    /// - Parameter scanlationGroupID: (Optional) Scanlation Group's 'UUID' of chapters
    /// - Parameter translatedLang: (Optional) Language of chapters
    /// - Returns: `Effect<...>` with either `Chapter` splitted in `Volumes` or `AppError`
    let fetchMangaChapters: (_ mangaID: UUID, _ scanlationGroupID: UUID?, _ translatedLang: String?) -> EffectPublisher<VolumesContainer, AppError>
    /// Fetch statistics for manga(bookmarks and rating)
    ///
    /// - Parameter mangaIDs: Manga's `UUIDs`, whose statistic are need to be fetched
    /// - Returns: `Effect<...>` with either Container of UUID - `MangaStatistics` or `AppError`
    let fetchStatistics: (_ mangaIDs: [UUID]) -> EffectPublisher<MangaStatisticsContainer, AppError>
    /// Fetch all `CoverArtInfo` for given MangaID
    ///
    /// - Parameter mangaID: Manga's `UUID`, whose `CoverArtInfo` are need to be fetched
    /// - Returns: `Effect<...>` with either sorted array(by `createdAt`, desc) of all `CoverArtInfo` or `AppError`
    let fetchAllCoverArtsForManga: (_ mangaID: UUID) -> EffectPublisher<Response<[CoverArtInfo]>, AppError>
    /// Fetch  `ChapterDetails` for given chapter ID
    ///
    /// - Parameter chapterID: Chapter ID of `ChapterDetails`, that need to be fetched
    /// - Returns: `Effect<...>` with either `Response<ChapterDetails>` or `AppError`
    let fetchChapterDetails: (_ chapterID: UUID) -> EffectPublisher<Response<ChapterDetails>, AppError>
    /// Fetch `ScanlationGroup` for given chapter ID
    ///
    /// - Parameter scanlationGroupID: ID of ScanlationGroup, can be found in `ChapterDetails`'s `Relationship`
    /// - Returns: `Effect<...>` with either `Response<ScanlationGroup>` or `AppError`
    let fetchScanlationGroup: (_ scanlationGroupID: UUID) -> EffectPublisher<Response<ScanlationGroup>, AppError>
    /// Fetch `PagesInfo` for given chapter
    ///
    /// - Parameter chapterID: ID of Chapter, can be found in `ChapterDetails`'s `Relationship`
    /// - Returns: `Effect<ScanlationGroup>` or AppError
    let fetchPagesInfo: (_ chapterID: UUID) -> EffectPublisher<ChapterPagesInfo, AppError>
    /// Fetch `CoverArtInfo` with given coverArtID
    ///
    /// - Parameter coverArtID: ID of CoverArt to be fetched
    /// - Returns: `Effect<...>` with either `Response<CoverArtInfo>` or `AppError`
    let fetchCoverArtInfo: (_ coverArtID: UUID) -> EffectPublisher<Response<CoverArtInfo>, AppError>
    /// Fetch `Author` with given ID
    ///
    /// - Parameter authorID: ID of Author to be fetched
    /// - Returns: `Effect<...>` with either `Response<Author>` or `AppError`
    let fetchAuthorByID: (_ authorID: UUID) -> EffectPublisher<Response<Author>, AppError>
    /// Fetch MangaFeed (aka `[ChapterDetails]`)
    ///
    /// - Parameter mangaID: ID of Manga to be fetched
    /// - Parameter offset: offset of feed
    /// - Returns: `Effect<...>` with either `Response<Author>` or `AppError`
    let fetchMangaFeed: (_ mangaID: UUID, _ offset: Int) -> EffectPublisher<Response<[ChapterDetails]>, AppError>
    
    // MARK: - Actions inside App
    /// Find in pages exact page with last read chapter index
    ///
    /// - Parameter chapterIndex: index of chapter, that user has read
    /// - Returns: `Int?` - if page found, than index of that page, otherwise `nil`
    let getMangaPageForReadingChapter: (_ chapterIndex: Double?, _ pages: [IdentifiedArrayOf<VolumeTabFeature.State>]) -> Int?
    let computeNextChapterIndex: (_ currentChapterIndex: Double?, _ chapters: [Chapter]?) -> Int?
    let computeChapterIndex: (_ chapterIndexToFind: Double?, _ chapters: [Chapter]?) -> Int?
    let computePreviousChapterIndex: (_ currentChapterIndex: Double?, _ chapters: [Chapter]?) -> Int?
    let findDidReadChapterOnMangaPage: (_ chapterIndex: Double?, IdentifiedArrayOf<VolumeTabFeature.State>) -> (volumeID: UUID, chapterID: UUID)?
    
    let saveCoverArt: (_ coverArt: UIImage, _ mangaID: UUID, _ cacheClient: CacheClient) -> EffectTask<Never>
    let deleteCoverArt: (_ mangaID: UUID, _ cacheClient: CacheClient) -> EffectTask<Never>
    let saveChapterPage: (_ chapterPage: UIImage, _ chapterPageIndex: Int, _ chapterID: UUID, _ cacheClient: CacheClient) -> EffectTask<Never>
    let removeCachedPagesForChapter: (_ chapterID: UUID, _ pagesCount: Int, _ cacheClient: CacheClient) -> EffectTask<Never>
    /// Check whether cover art for manga cached or not
    ///
    /// - Parameter mangaID: ID of manga, whose cover art need to be checked
    /// - Parameter cacheClient: `CacheClient`
    /// - Returns: `Bool` - if cached `true`, otherwise - `false`
    let isCoverArtCached: (_ mangaID: UUID, _ cacheClient: CacheClient) -> Bool
    /// Get all pathes for cached chapter's pages
    ///
    /// - Parameter chapterID: ID of chapter, whose pages's paths are need to be found
    /// - Parameter pagesCount: Count of pages in the chapter, whose ID was given
    /// - Parameter cacheClient: `CacheClient`
    /// - Returns: `[URL?]` - array of `Optional(URL)` leading to cached pages
    let getPathsForCachedChapterPages: (_ chapterID: UUID, _ pagesCount: Int, _ cacheClient: CacheClient) -> [URL?]
    /// Get path on disk for manga's cover art
    ///
    /// - Parameter mangaID: ID of manga, whose cover art is need to be found
    /// - Parameter cacheClient: `CacheClient`
    /// - Returns: `URL`, leading to cover art or `nil`
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

extension MangaClient: DependencyKey {
    static let liveValue = MangaClient(
        fetchMangaChapters: { mangaID, scanlationGroupID, translatedLanguage in
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/manga/\(mangaID.uuidString.lowercased())/aggregate"
            
            components.queryItems = []
            
            if let scanlationGroupID {
                components.queryItems!.append(
                    URLQueryItem(name: "groups[]", value: scanlationGroupID.uuidString.lowercased())
                )
            }
            
            if let translatedLanguage {
                components.queryItems!.append(
                    URLQueryItem(name: "translatedLanguage[]", value: translatedLanguage)
                )
            }
            
            guard let url = components.url else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: VolumesContainer.self)
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
        fetchAuthorByID: { authorID in
            guard let url = URL(string: "https://api.mangadex.org/author/\(authorID.uuidString.lowercased())?includes[]=manga") else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<Author>.self)
        },
        fetchMangaFeed: { mangaID, offset in
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.mangadex.org"
            components.path = "/manga/\(mangaID.uuidString.lowercased())/feed"
            
            components.queryItems = [
                URLQueryItem(name: "includes[]", value: "scanlation_group"),
                URLQueryItem(name: "order[volume]", value: "desc"),
                URLQueryItem(name: "order[chapter]", value: "desc"),
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "limit", value: "500"),
                URLQueryItem(name: "contentRating[]", value: "safe"),
                URLQueryItem(name: "contentRating[]", value: "suggestive"),
                URLQueryItem(name: "contentRating[]", value: "erotica"),
                URLQueryItem(name: "contentRating[]", value: "pornographic")
            ]
            
            guard let url = components.url else {
                return .none
            }
            
            return URLSession.shared.get(url: url, decodeResponseAs: Response<[ChapterDetails]>.self)
        },
        getMangaPageForReadingChapter: { chapterIndex, pages in
            // chapterIndex - index of current reading chapter
            // we find it among all chapters and send user to this page
            guard let chapterIndex else { return nil }
            
            for (pageIndex, page) in pages.enumerated() {
                for volumeState in page {
                    // swiftlint:disable:next for_where
                    if volumeState.chapterStates.first(where: { $0.chapter.index == chapterIndex }).hasValue {
                        return pageIndex
                    }
                }
            }
            
            return nil
        },
        computeNextChapterIndex: { currentChapterIndex, chapters in
            guard let chapterIndex = chapters?.firstIndex(where: { $0.index == currentChapterIndex }) else {
                return nil
            }
            
            return chapterIndex + 1 < chapters!.count ? chapterIndex + 1 : nil
        },
        computeChapterIndex: { chapterIndex, chapters in
            guard let chapterIndex = chapters?.firstIndex(where: { $0.index == chapterIndex }) else {
                return nil
            }
            
            return chapterIndex >= 0 && chapterIndex < chapters!.count ? chapterIndex : nil
        },
        computePreviousChapterIndex: { currentChapterIndex, chapters in
            // 'currentChapterIndex' - is index(Double) and may not match with index in 'chapters'
            guard let chapterIndex = chapters?.firstIndex(where: { $0.index == currentChapterIndex }) else {
                return nil
            }
            
            return chapterIndex > 0 ? chapterIndex - 1 : nil
        },
        findDidReadChapterOnMangaPage: { chapterIndex, volumes in
            for volumeStateID in volumes.ids {
                for chapterStateID in volumes[id: volumeStateID]!.chapterStates.ids {
                    let chapterState = volumes[id: volumeStateID]!.chapterStates[id: chapterStateID]!
                    
                    if chapterState.chapter.index == chapterIndex {
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
        deleteCoverArt: { mangaID, cacheClient in
            let imageName = getCoverArtName(mangaID: mangaID)
            
            return cacheClient.removeImage(imageName).fireAndForget()
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
