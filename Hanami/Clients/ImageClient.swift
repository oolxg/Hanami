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
    let prefetchImages: ([URL], KingfisherOptionsInfo?) -> Effect<Never, Never>
    let downloadImage: (URL, KingfisherOptionsInfo?) -> Effect<Result<UIImage, Error>, Never>
}

extension ImageClient {
    static var live = ImageClient(
        prefetchImages: { urls, options in
            .fireAndForget {
                ImagePrefetcher(urls: urls, options: options).start()
            }
        },
        downloadImage: { url, options in
            Future { promise in
                KingfisherManager.shared.downloader.downloadImage(with: url, options: options) { result in
                    switch result {
                        case .success(let response):
                            return promise(.success(response.image))
                        case .failure(let error):
                            return promise(.failure(error))
                    }
                }
            }
            .retry(3)
            .catchToEffect()
        }
    )
}
