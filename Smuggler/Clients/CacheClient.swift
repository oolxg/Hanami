//
//  CacheClient.swift
//  Smuggler
//
//  Created by mk.pwnz on 24/07/2022.
//

import Cache
import ComposableArchitecture
import Combine
import class SwiftUI.UIImage

struct CacheClient {
    private static let dataStorage: Storage<String, Data> = {
        let diskConfig = DiskConfig(
            name: "Kamakura_Storage",
            expiry: .never,
            // swiftlint:disable:next force_try
            directory: try! FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("images")
        )
        
        let memoryConfig = MemoryConfig(expiry: .never)
        
        // swiftlint:disable:next force_try
        return try! Storage(
            diskConfig: diskConfig,
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: Data.self)
        )
    }()
    
    private static let imageStorage = dataStorage.transformImage()
    
    let cacheImage: (UIImage, String) -> Effect<Never, Never>
    let retrieveImage: (String) -> Effect<Swift.Result<UIImage, Error>, Never>
    let removeImage: (String) -> Effect<Never, Never>
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
                            print("[CacheClient] - Error on caching image:", err.localizedDescription)
                    }
                }
            }
        },
        retrieveImage: { imageName in
            Future { promise in
                imageStorage.async.object(forKey: imageName) { result in
                    switch result {
                        case .value(let image):
                            promise(.success(image))
                        case .error(let error):
                            promise(.failure(error))
                    }
                }
            }
            .eraseToAnyPublisher()
            .catchToEffect()
        },
        removeImage: { imageName in
                .fireAndForget {
                    imageStorage.async.removeObject(forKey: imageName) { result in
                        switch result {
                            case .value:
                                break
                            case .error(let err):
                                print("[CacheClient] - Error on removing image:", err.localizedDescription)
                        }
                    }
                }
        }
    )
}
