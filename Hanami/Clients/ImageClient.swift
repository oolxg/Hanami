//
//  ImageClient.swift
//  Hanami
//
//  Created by Oleg on 11/08/2022.
//

import Combine
import ComposableArchitecture
import Nuke
import Foundation
import class SwiftUI.UIImage

extension DependencyValues {
    var imageClient: ImageClient {
        get { self[ImageClient.self] }
        set { self[ImageClient.self] = newValue }
    }
}

struct ImageClient {
    let prefetchImages: ([URL]) -> EffectTask<Never>
    let downloadImage: (URL) -> EffectTask<Result<UIImage, AppError>>
    
    private static let prefetcher = ImagePrefetcher(maxConcurrentRequestCount: 5)
}

extension ImageClient: DependencyKey {
    static let liveValue = ImageClient(
        prefetchImages: { urls in
            .fireAndForget {
                prefetcher.startPrefetching(with: urls)
            }
        },
        downloadImage: { url in
            Future { promise in
                DispatchQueue.global().async {
                    do {
                        let data = try Data(contentsOf: url)
                        guard let image = UIImage(data: data) else {
                            return promise(.failure(.imageError("Bad data, can't decode it to image")))
                        }
                        
                        return promise(.success(image))
                    } catch {
                        if let urlError = error as? URLError {
                            promise(.failure(.networkError(urlError)))
                        } else if let decodingError = error as? DecodingError {
                            promise(.failure(.decodingError(decodingError)))
                        } else {
                            promise(.failure(.unknownError(error)))
                        }
                    }
                }
            }
            .retry(3)
            .catchToEffect()
        }
    )
}
