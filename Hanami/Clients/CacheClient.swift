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

extension DependencyValues {
    var cacheClient: CacheClient {
        get { self[CacheClient.self] }
        set { self[CacheClient.self] = newValue }
    }
}

struct CacheClient {
    private static let imagesCachePath = FileUtil.documentDirectory.appendingPathComponent("images")
    
    private static let cacheQueue = DispatchQueue(
        label: "moe.mkpwnz.Hanami.CacheClient",
        qos: .utility,
        attributes: .concurrent
    )
    
    private static let imageStorage: DiskStorage<String, Image> = {
        let diskConfig = DiskConfig(
            name: "HanamiImages",
            expiry: .never,
            directory: imagesCachePath
        )
        
        // swiftlint:disable:next force_try
        return try! DiskStorage(
            config: diskConfig,
            fileManager: FileManager(),
            transformer: TransformerFactory.forImage()
        )
    }()
    
    // MangaID -> set of cached chapterIDs
    private static let cachedChapterIDsStorage: MemoryStorage<UUID, Set<UUID>> = {
        let config = MemoryConfig(expiry: .never)
        
        return MemoryStorage(config: config)
    }()
    
    /* Saving images on disk methods */
    /// Saves image with given name `imageName` on disk
    ///
    /// - Parameter image: `UIImaga` to be cached
    /// - Parameter imageName: `imageName` name of the image
    /// - Returns: ` EffectTask<Never>`
    let cacheImage: (_ image: UIImage, _ imageName: String) ->  EffectTask<Never>
    /// Removes image with `imageName` from disk
    ///
    /// - Parameter imageName: `imageName` name of the image to be removed
    /// - Returns: ` EffectTask<Never>`
    let removeImage: (String) ->  EffectTask<Never>
    /// Checks whether image is cached on disk or not
    ///
    /// - Parameter imageName: name of the image to be checked
    /// - Returns: `Bool`: `true` if image is cached, otherwise `false`
    let isCached: (String) -> Bool
    /// Removes all images from cache
    ///
    /// - Note: Doesn't affect Nuke cache
    ///
    /// - Returns: ` EffectTask<Never>`
    let clearCache: () ->  EffectTask<Never>
    /// Computes cache for all save on disk images
    ///
    /// - Note: Doesn't compute Nuke cache
    ///
    /// - Returns: `EffectTask<Swift.Result<Double, AppError>>`: `Double` - cached size in Megabytes
    let computeCacheSize: () ->  EffectTask<Swift.Result<Double, AppError>>
    /// Returns path for image with given `imageName`
    ///
    /// - Note: Doesn't affect cached images in Nuke
    ///
    /// - Returns: `URL`: `URL`-location on disk if image was found, otherwise `nil`
    let pathForImage: (_ fileName: String) -> URL?
    /* Saving images on disk methods END */

    /// Saves id of cached chapter for manga in memory
    ///
    /// - Parameter mangaID: `UUID` parent manga ID
    /// - Parameter chapterIDs: `Set<UUID>` of the chapters to be cached in memory
    /// - Returns: `EffectTask<Never>`
    let saveCachedChaptersInMemory: (_ mangaID: UUID, _ chapterIDs: Set<UUID>) -> EffectTask<Never>
    /// Saves id of cached chapter for manga in memory
    ///
    /// - Parameter mangaID: `UUID` parent manga ID
    /// - Parameter chapterID: `UUID` of the chapter to be cached in memory
    /// - Returns: `EffectTask<Never>`
    let saveCachedChapterInMemory: (_ mangaID: UUID, _ chapterIDs: UUID) -> EffectTask<Never>
    /// Retrieved id of cached chapter for manga in memory
    ///
    /// - Parameter mangaID: `UUID` parent manga ID
    /// - Returns: `Set<UUID>`: Set of cached chaptes
    let retrieveFromMemoryCachedChapters: (_ mangaID: UUID) -> EffectPublisher<Set<UUID>, AppError>
    /// Removes all chapter IDs from list of cached chapters in manga
    ///
    /// - Parameter mangaID: `UUID` manga id, whose chapter are gonna be removed from memory
    /// - Returns: `EffectTask<Never>`
    let removeAllCachedChapterIDsFromMemory: (_ mangaID: UUID) -> EffectTask<Never>
    /// Removes chapter ID from list of cached chapters in manga
    ///
    /// - Parameter mangaID: `UUID` of the manga, whose chapter is gonna be deleted from memory
    /// - Parameter chapterID: `UUID` of the not more cached chapter to be removed from memory
    /// - Returns: `EffectTask<Never>`
    let removeCachedChapterIDFromMemory: (_ mangaID: UUID, _ chapterID: UUID) -> EffectTask<Never>
}

extension CacheClient: DependencyKey {
    static let liveValue = CacheClient(
        cacheImage: { image, imageName in
            .fireAndForget {
                cacheQueue.async {
                    try? imageStorage.setObject(image, forKey: imageName, expiry: .never)
                }
            }
        },
        removeImage: { imageName in
            .fireAndForget {
                cacheQueue.async {
                    try? imageStorage.removeObject(forKey: imageName)
                }
            }
        },
        isCached: { imageName in
            guard let result = try? imageStorage.existsObject(forKey: imageName) else { return false }
            return result
        },
        clearCache: {
            .fireAndForget {
                cacheQueue.async {
                    try? imageStorage.removeAll()
                }
            }
        },
        computeCacheSize: {
            Future { promise in
                cacheQueue.async {
                    guard let size = CacheClient.imagesCachePath.sizeOnDisk() else {
                        promise(.failure(.cacheError("Can't compute cache size")))
                        return
                    }
                    promise(.success(size))
                }
            }
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
                cacheQueue.async {
                    cachedChapterIDsStorage.setObject(chapterIDs, forKey: mangaID)
                }
            }
        },
        saveCachedChapterInMemory: { mangaID, chapterID in
            .fireAndForget {
                cacheQueue.async {
                    if var savedChapters = try? cachedChapterIDsStorage.object(forKey: mangaID) {
                        savedChapters.insert(chapterID)
                        cachedChapterIDsStorage.setObject(savedChapters, forKey: mangaID)
                    } else {
                        cachedChapterIDsStorage.setObject([chapterID], forKey: mangaID)
                    }
                }
            }
        },
        retrieveFromMemoryCachedChapters: { mangaID in
            Future { promise in
                cacheQueue.async {
                    if let cachedChapterIDs = try? cachedChapterIDsStorage.object(forKey: mangaID) {
                        promise(.success(cachedChapterIDs))
                        return
                    }
                    
                    promise(.failure(.notFound))
                }
            }
            .eraseToEffect()
        },
        removeAllCachedChapterIDsFromMemory: { mangaID in
            .fireAndForget {
                cacheQueue.async {
                    // we have to store empty set for recently deleted manga to avoid some UI bugs
                    cachedChapterIDsStorage.setObject([], forKey: mangaID)
                }
            }
        },
        removeCachedChapterIDFromMemory: { mangaID, chapterID in
            .fireAndForget {
                cacheQueue.async {
                    if var cachedChapterIDs = try? cachedChapterIDsStorage.object(forKey: mangaID) {
                        // its already cached chapters from this manga
                        cachedChapterIDs.remove(chapterID)
                        cachedChapterIDsStorage.setObject(cachedChapterIDs, forKey: mangaID)
                    }
                }
            }
        }
    )
}
