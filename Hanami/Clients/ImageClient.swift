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

struct ImageClient {
    let prefetchImages: ([URL]) -> Effect<Never, Never>
    let downloadImage: (URL) -> Effect<Result<UIImage, AppError>, Never>
}

extension ImageClient {
    static var live = ImageClient(
        prefetchImages: { urls in
            .fireAndForget {
                ImagePrefetcher().startPrefetching(with: urls)
            }
        },
        downloadImage: { url in
            Future { promise in
                DispatchQueue.global().async {
                    if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                        return promise(.success(image))
                    }
                    
                    return promise(.failure(.networkError(URLError(URLError.Code.badServerResponse))))
                }
            }
            .retry(3)
            .catchToEffect()
        }
    )
}
