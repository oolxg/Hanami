//
//  ImageClient.swift
//  Smuggler
//
//  Created by mk.pwnz on 11/08/2022.
//

import Combine
import ComposableArchitecture
import Kingfisher
import class SwiftUI.UIImage

struct ImageClient {
    let prefetchImages: ([URL]) -> Effect<Never, Never>
    let downloadImage: (URL) -> Effect<Result<UIImage, Error>, Never>
}

extension ImageClient {
    static var live = ImageClient(
        prefetchImages: { urls in
            .fireAndForget {
                ImagePrefetcher(urls: urls).start()
            }
        },
        downloadImage: { url in
            Future { promise in
                KingfisherManager.shared.downloader.downloadImage(with: url) { result in
                    switch result {
                        case .success(let result):
                            promise(.success(result.image))
                        case .failure(let error):
                            promise(.failure(error))
                    }
                }
            }
            .eraseToAnyPublisher()
            .catchToEffect()
        }
    )
}
