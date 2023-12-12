import Foundation
import Dependencies
import class SwiftUI.UIImage
import ModelKit
import Utils
import CacheClient
import DataTypeExtensions

public extension DependencyValues {
    var mangaClient: MangaClient {
        get { self[MangaClient.self] }
        set { self[MangaClient.self] = newValue }
    }
}

public struct MangaClient {
    @Dependency(\.cacheClient) private var cacheClient
    // MARK: - Manage info for offline reading
    private func getCoverArtName(mangaID: UUID) -> String {
        "coverArt-\(mangaID.uuidString.lowercased())"
    }
    private func getChapterPageName(chapterID: UUID, pageIndex: Int) -> String {
        "\(chapterID.uuidString.lowercased())-\(pageIndex)"
    }
    
    private init() { }
    
    public func fetchChapters(forMangaWithID mangaID: UUID, scanlationGroupID: UUID? = nil, translatedLanguage: String? = nil) async -> Result<VolumesContainer, AppError> {
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
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: VolumesContainer.self)
    }
    
    public func fetchStatistics(for mangaIDs: [UUID]) async -> Result<MangaStatisticsContainer, AppError> {
        guard !mangaIDs.isEmpty else {
            return .success(MangaStatisticsContainer(statistics: [:]))
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.mangadex.org"
        components.path = "/statistics/manga"
        components.queryItems = mangaIDs.map {
            URLQueryItem(name: "manga[]", value: $0.uuidString.lowercased())
        }
        
        guard let url = components.url else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: MangaStatisticsContainer.self)
    }
    
    public func fetchAllCoverArts(forManga mangaID: UUID) async -> Result<Response<[CoverArtInfo]>, AppError> {
        let mangaIDString = mangaID.uuidString.lowercased()
        guard let url = URL(string: "https://api.mangadex.org/cover?order[volume]=asc&manga[]=\(mangaIDString)&limit=100") else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<[CoverArtInfo]>.self)
    }
    
    public func fetchChapterDetails(for chapterID: UUID) async -> Result<Response<ChapterDetails>, AppError> {
        let chapterIDString = chapterID.uuidString.lowercased()
        guard let url = URL(string: "https://api.mangadex.org/chapter/\(chapterIDString)?includes[]=scanlation_group") else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<ChapterDetails>.self)
    }
    
    public func fetchScanlationGroup(for scanlationGroupID: UUID) async -> Result<Response<ScanlationGroup>, AppError> {
        let scanlationGroupIDString = scanlationGroupID.uuidString.lowercased()
        guard let url = URL(string: "https://api.mangadex.org/group/\(scanlationGroupIDString)") else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<ScanlationGroup>.self)
    }
    
    public func fetchPagesInfo(for chapterID: UUID) async -> Result<ChapterPagesInfo, AppError> {
        let chapterIDString = chapterID.uuidString.lowercased()
        guard let url = URL(string: "https://api.mangadex.org/at-home/server/\(chapterIDString)") else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: ChapterPagesInfo.self)
    }

    public func fetchCoverArtInfo(for coverArtID: UUID) async -> Result<Response<CoverArtInfo>, AppError> {
        guard let url = URL(string: "https://api.mangadex.org/cover/\(coverArtID.uuidString.lowercased())") else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<CoverArtInfo>.self)
    }
    
    public func fetchAuthor(authorID: UUID) async -> Result<Response<Author>, AppError> {
        guard let url = URL(string: "https://api.mangadex.org/author/\(authorID.uuidString.lowercased())?includes[]=manga") else {
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<Author>.self)
    }
    
    public func fetchFeed(forManga mangaID: UUID, offset: Int) async -> Result<Response<[ChapterDetails]>, AppError> {
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
            return .failure(.networkError(URLError(.badURL)))
        }
        
        return await URLSession.shared.get(url: url, decodeResponseAs: Response<[ChapterDetails]>.self)
    }
    
    public func getNextChapterIndex(currentChapterIndex: Double?, scanlationGroupChapters chapters: [Chapter]?) -> Int? {
        guard let chapterIndex = chapters?.firstIndex(where: { $0.index == currentChapterIndex }) else {
            return nil
        }
        
        return chapterIndex + 1 < chapters!.count ? chapterIndex + 1 : nil
    }
    
    public func getChapterIndex(chapterIndexToFind chapterIndex: Double?, scanlationGroupChapters chapters: [Chapter]?) -> Int? {
        guard let chapterIndex = chapters?.firstIndex(where: { $0.index == chapterIndex }) else {
            return nil
        }
        
        return chapterIndex >= 0 && chapterIndex < chapters!.count ? chapterIndex : nil
    }
    
    public func getPrevChapterIndex(currentChapterIndex: Double?, scanlationGroupChapters chapters: [Chapter]?) -> Int? {
        guard let chapterIndex = chapters?.firstIndex(where: { $0.index == currentChapterIndex }) else {
            return nil
        }
        
        return chapterIndex > 0 ? chapterIndex - 1 : nil
    }
    
    public func saveCoverArt(_ coverArt: UIImage, from mangaID: UUID) {
        let imageName = getCoverArtName(mangaID: mangaID)
        
        cacheClient.cacheImage(image: coverArt, withName: imageName)
    }
    
    public func deleteCoverArt(for mangaID: UUID) {
        let imageName = getCoverArtName(mangaID: mangaID)
        
        cacheClient.removeImage(withName: imageName)
    }
    
    public func saveChapterPage(_ chapterPage: UIImage, withIndex pageIndex: Int, chapterID: UUID) {
        let imageName = getChapterPageName(chapterID: chapterID, pageIndex: pageIndex)
        
        cacheClient.cacheImage(image: chapterPage, withName: imageName)
    }
    
    public func removeCachedPagesForChapter(_ chapterID: UUID, pagesCount: Int) {
        for pageIndex in 0..<pagesCount {
            let imageName = getChapterPageName(chapterID: chapterID, pageIndex: pageIndex)
            cacheClient.removeImage(withName: imageName)
        }
    }
    
    public func isCoverArtCached(forManga mangaID: UUID) -> Bool {
        let imageName = getCoverArtName(mangaID: mangaID)
        
        return cacheClient.isCached(imageName)
    }
    
    public func getPathsForCachedChapterPages(chapterID: UUID, pagesCount: Int) -> [URL?] {
        (0..<pagesCount).indices.map { pageIndex in
            cacheClient.pathFor(image: getChapterPageName(chapterID: chapterID, pageIndex: pageIndex))
        }
    }
    
    public func getCoverArtPath(for mangaID: UUID) -> URL? {
        cacheClient.pathFor(image: getCoverArtName(mangaID: mangaID))
    }
}

extension MangaClient: DependencyKey {
    public static var liveValue = MangaClient()
}
