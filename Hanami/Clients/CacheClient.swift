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
    
    private static let imageStorage: Storage<String, Image> = {
        let diskConfig = DiskConfig(
            name: "Kamakura_Storage",
            expiry: .never,
            directory: CacheFolderPathes.imagesCachePath
        )
        
        let memoryConfig = MemoryConfig(expiry: .never)
        
        // swiftlint:disable:next force_try
        return try! Storage(
            diskConfig: diskConfig,
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forImage()
        )
    }()
    
    let cacheImage: (UIImage, String) -> Effect<Never, Never>
    let removeImage: (String) -> Effect<Never, Never>
    let isCached: (String) -> Bool
    let clearCache: () -> Effect<Never, Never>
    let computeCacheSize: () -> Effect<Swift.Result<Double, AppError>, Never>
    let pathForImage: (_ fileName: String) -> URL?
}

extension CacheClient {
    static let live = CacheClient(
        cacheImage: { image, imageName in
            .fireAndForget {
                imageStorage.async.setObject(image, forKey: imageName) { result in
                    switch result {
                        case .value:
                            break
                        case .error(let err):
                            print("[CacheClient] - Error on caching image:", err.localizedDescription, err)
                    }
                }
            }
        },
        removeImage: { imageName in
            .fireAndForget {
                imageStorage.async.removeObject(forKey: imageName) { result in
                    switch result {
                        case .value:
                            break
                        case .error(let err):
                            print("[CacheClient] - Error on removing image:", err.localizedDescription, err)
                    }
                }
            }
        },
        isCached: { imageName in
            // force try can be used, because the function 'existsObject(forKey: )' is only marked as throws,
            // but it does no throw 
            // swiftlint:disable:next force_try
            try! imageStorage.existsObject(forKey: imageName)
        },
        clearCache: {
            .fireAndForget {
                imageStorage.async.removeAll { result in
                    switch result {
                        case .value:
                            break
                            
                        case .error(let error):
                            print("Error on clearing cache:", error)
                    }
                }
            }
        }, computeCacheSize: {
            Future { promise in
                DispatchQueue.main.async {
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
        }
    )
}
