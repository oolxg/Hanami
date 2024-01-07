//
//  CacheClient.swift
//  Hanami
//
//  Created by Oleg on 24/07/2022.
//

import Cache
import Dependencies
import Combine
import Foundation
import class SwiftUI.UIImage
import Utils
import DataTypeExtensions

public extension DependencyValues {
    var cacheClient: CacheClient {
        get { self[CacheClient.self] }
        set { self[CacheClient.self] = newValue }
    }
}

public struct CacheClient: DependencyKey {
    public static let liveValue = CacheClient()
    
    private static let imagesCachePath = FileUtil.documentDirectory.appendingPathComponent("images")
    
    private let cacheQueue = DispatchQueue(
        label: "moe.mkpwnz.Hanami.CacheClient",
        qos: .utility,
        attributes: .concurrent
    )
    
    private let imageStorage: DiskStorage<String, Image> = {
        let diskConfig = DiskConfig(
            name: "HanamiImages",
            expiry: .never,
            directory: Self.imagesCachePath
        )
        
        // swiftlint:disable:next force_try
        return try! DiskStorage(
            config: diskConfig,
            fileManager: FileManager(),
            transformer: TransformerFactory.forImage()
        )
    }()
    
    private init() { }
    
    // MangaID -> set of cached chapterIDs
    private let cachedChapterIDsStorage: MemoryStorage<UUID, Set<UUID>> = {
        let config = MemoryConfig(expiry: .never)
        
        return MemoryStorage(config: config)
    }()
    
    public func cacheImage(image: UIImage, withName imageName: String) {
        cacheQueue.async {
            try? imageStorage.setObject(image, forKey: imageName, expiry: .never)
        }
    }
    
    public func removeImage(withName imageName: String) {
        cacheQueue.async {
            try? imageStorage.removeObject(forKey: imageName)
        }
    }
    
    public func isCached(_ imageName: String) -> Bool {
        guard let result = try? imageStorage.existsObject(forKey: imageName) else { return false }
        return result
    }
    
    public func clearCache() {
        cacheQueue.async {
            try? imageStorage.removeAll()
        }
    }
    
    public func computeCacheSize() async -> Swift.Result<Double, AppError> {
        await withCheckedContinuation { continuation in
            cacheQueue.async {
                guard let size = Self.imagesCachePath.sizeOnDisk() else {
                    continuation.resume(returning: .failure(AppError.cacheError("Can't compute cache size")))
                    return
                }
                continuation.resume(returning: .success(size))
            }
        }
    }
    
    public func pathFor(image imageName: String) -> URL? {
        if let path = try? imageStorage.entry(forKey: imageName).filePath {
            return URL(string: "file://\(path)")
        }
        
        return nil
    }
    
    public func replaceCachedChaptersInMemory(mangaID: UUID, chapterIDs: Set<UUID>) {
        cacheQueue.async {
            cachedChapterIDsStorage.setObject(chapterIDs, forKey: mangaID)
        }
    }
    
    public func saveCachedChapterInMemory(mangaID: UUID, chapterID: UUID) {
        cacheQueue.async {
            if var savedChapters = try? cachedChapterIDsStorage.object(forKey: mangaID) {
                savedChapters.insert(chapterID)
                cachedChapterIDsStorage.setObject(savedChapters, forKey: mangaID)
            } else {
                cachedChapterIDsStorage.setObject([chapterID], forKey: mangaID)
            }
        }
    }
    
    public func retrieveFromMemoryCachedChapters(for mangaID: UUID) async throws -> Set<UUID> {
        try await withCheckedThrowingContinuation { continuation in
            cacheQueue.async {
                if let cachedChapterIDs = try? cachedChapterIDsStorage.object(forKey: mangaID) {
                    continuation.resume(returning: cachedChapterIDs)
                    return
                }

                continuation.resume(throwing: AppError.notFound)
            }
        }
    }
    
    public func removeAllCachedChapterIDsFromMemory(for mangaID: UUID) {
        cacheQueue.async {
            // we have to store empty set for recently deleted manga to avoid some UI bugs
            cachedChapterIDsStorage.setObject([], forKey: mangaID)
        }
    }
    
    public func removeCachedChapterIDFromMemory(for mangaID: UUID, chapterID: UUID) {
        cacheQueue.async {
            if var cachedChapterIDs = try? cachedChapterIDsStorage.object(forKey: mangaID) {
                // its already cached chapters from this manga
                cachedChapterIDs.remove(chapterID)
                cachedChapterIDsStorage.setObject(cachedChapterIDs, forKey: mangaID)
            }
        }
    }
}
