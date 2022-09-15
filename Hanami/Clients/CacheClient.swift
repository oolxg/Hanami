//
//  CacheClient.swift
//  Hanami
//
//  Created by Oleg on 24/07/2022.
//

import Cache
import ComposableArchitecture
import Combine
import Foundation
import class SwiftUI.UIImage

struct CacheClient {
    private enum CacheFolderPathes {
        private static let storagePathURL: URL = {
                // swiftlint:disable:next force_try
            try! FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }()
        
        static let imagesCachePath = storagePathURL.appendingPathComponent("images")
    }
    
    private static let queue = DispatchQueue(label: "CacheQueue", qos: .utility)
    
    private static let imageStorage: DiskStorage<String, Image> = {
        let diskConfig = DiskConfig(
            name: "Kamakura_Storage",
            expiry: .never,
            directory: CacheFolderPathes.imagesCachePath
        )
        
        // swiftlint:disable:next force_try
        return try! DiskStorage(
            config: diskConfig,
            fileManager: FileManager(),
            transformer: TransformerFactory.forImage()
        )
    }()
    
    // Manga -> set of cached chapterIDs
    private static let cachedChapterIDsStorage: MemoryStorage<UUID, Set<UUID>> = {
        let fifteenMinutes = Expiry.seconds(15 * 60)
        let config = MemoryConfig(expiry: fifteenMinutes)
        
        return MemoryStorage(config: config)
    }()
    
    /* Saving images on disk methods */
    /// Saves image with given name `imageName` on disk
    ///
    /// - Parameter image: `UIImaga` to be cached
    /// - Parameter imageName: `imageName` name of the image
    /// - Returns: `Effect<Never, Never>`
    let cacheImage: (_ image: UIImage, _ imageName: String) -> Effect<Never, Never>
    /// Removes image with `imageName` from disk
    ///
    /// - Parameter imageName: `imageName` name of the image to be removed
    /// - Returns: `Effect<Never, Never>`
    let removeImage: (String) -> Effect<Never, Never>
    /// Checks whether image is cached on disk or not
    ///
    /// - Parameter imageName: name of the image to be checked
    /// - Returns: `Bool`: `true` if image is cached, otherwise `false`
    let isCached: (String) -> Bool
    /// Removes all images from cache
    ///
    /// - Note: Doesn't affect Kingfisher cache
    ///
    /// - Returns: `Effect<Never, Never>`
    let clearCache: () -> Effect<Never, Never>
    /// Computes cache for all save on disk images
    ///
    /// - Note: Doesn't compute Kingfisher cache
    ///
    /// - Returns: `Effect<Result<Double, AppError>, Never>`: `Double` - cached size in Megabytes
    let computeCacheSize: () -> Effect<Swift.Result<Double, AppError>, Never>
    /// Returns path for image with given `imageName`
    ///
    /// - Note: Doesn't affect cached images in Kingfisher
    ///
    /// - Returns: `URL`: `URL`-location on disk if image was found, otherwise `nil`
    let pathForImage: (_ fileName: String) -> URL?
    /* Saving images on disk methods END */

    /// Saves id of cached chapter for manga in memory
    ///
    /// - Parameter mangaID: `UUID` parent manga ID
    /// - Parameter chapterIDs: `Set<UUID>` of the chapters to be cached in memory
    /// - Returns: `Effect<Never, Never>`
    let saveCachedChaptersInMemory: (_ mangaID: UUID, _ chapterIDs: Set<UUID>) -> Effect<Never, Never>
    /// Saves id of cached chapter for manga in memory
    ///
    /// - Parameter mangaID: `UUID` parent manga ID
    /// - Parameter chapterID: `UUID` of the chapter to be cached in memory
    /// - Returns: `Effect<Never, Never>`
    let saveCachedChapterInMemory: (_ mangaID: UUID, _ chapterIDs: UUID) -> Effect<Never, Never>
    /// Retrieved id of cached chapter for manga in memory
    ///
    /// - Parameter mangaID: `UUID` parent manga ID
    /// - Returns: `Set<UUID>`: Set of cached chaptes
    let retrieveFromMemoryCachedChapters: (_ mangaID: UUID) -> Set<UUID>
    /// Removes all chapter IDs from list of cached chapters in manga
    ///
    /// - Parameter mangaID: `UUID` manga id, whose chapter are gonna be removed from memory
    /// - Returns: `Effect<Never, Never>`
    let removeAllCachedChapterIDsFromMemory: (_ mangaID: UUID) -> Effect<Never, Never>
    /// Removes chapter ID from list of cached chapters in manga
    ///
    /// - Parameter mangaID: `UUID` of the manga, whose chapter is gonna be deleted from memory
    /// - Parameter chapterID: `UUID` of the not more cached chapter to be removed from memory
    /// - Returns: `Effect<Never, Never>`
    let removeCachedChapterIDFromMemory: (_ mangaID: UUID, _ chapterID: UUID) -> Effect<Never, Never>
}

extension CacheClient {
    static let live = CacheClient(
        cacheImage: { image, imageName in
                .fireAndForget {
                    queue.async {
                        try? imageStorage.setObject(image, forKey: imageName, expiry: .never)
                    }
                }
        },
        removeImage: { imageName in
                .fireAndForget {
                    queue.async {
                        try? imageStorage.removeObject(forKey: imageName)
                    }
                }
        },
        isCached: { imageName in
            // force try can be used, because the function 'existsObject(forKey: )' is only marked as `throws`,
            // but it does not throw
            // swiftlint:disable:next force_try
            try! imageStorage.existsObject(forKey: imageName)
        },
        clearCache: {
            .fireAndForget {
                queue.async {
                    try? imageStorage.removeAll()
                }
            }
        },
        computeCacheSize: {
            Future { promise in
                queue.async {
                    guard let size = CacheFolderPathes.imagesCachePath.sizeOnDisk() else {
                        promise(.failure(.cacheError("Can't compute cache size")))
                        return
                    }
                    promise(.success(size))
                }
            }
            .receive(on: DispatchQueue.main)
            .catchToEffect()
        },
        pathForImage: { fileName in
            if let path = try? imageStorage.entry(forKey: fileName).filePath {
                return URL(string: "file://\(path)")
            }
            
            return nil
        },
        saveCachedChaptersInMemory: { mangaID, chapterIDs in
            .fireAndForget {
                cachedChapterIDsStorage.setObject(chapterIDs, forKey: mangaID)
            }
        },
        saveCachedChapterInMemory: { mangaID, chapterID in
            .fireAndForget {
                if var savedChapters = try? cachedChapterIDsStorage.object(forKey: mangaID) {
                    savedChapters.insert(chapterID)
                    cachedChapterIDsStorage.setObject(savedChapters, forKey: mangaID)
                } else {
                    cachedChapterIDsStorage.setObject([chapterID], forKey: mangaID)
                }
            }
        },
        retrieveFromMemoryCachedChapters: { mangaID in
            if let cachedChapterIDs = try? cachedChapterIDsStorage.object(forKey: mangaID) {
                return cachedChapterIDs
            }
            
            return []
        },
        removeAllCachedChapterIDsFromMemory: { mangaID in
            .fireAndForget {
                cachedChapterIDsStorage.removeObject(forKey: mangaID)
            }
        },
        removeCachedChapterIDFromMemory: { mangaID, chapterID in
            .fireAndForget {
                if var cachedChapterIDs = try? cachedChapterIDsStorage.object(forKey: mangaID) {
                    // there're already cached chapters this manga
                    cachedChapterIDs.remove(chapterID)
                    if cachedChapterIDs.isEmpty {
                        cachedChapterIDsStorage.removeObject(forKey: mangaID)
                    } else {
                        cachedChapterIDsStorage.setObject(cachedChapterIDs, forKey: mangaID)
                    }
                }
            }
        }
    )
}
