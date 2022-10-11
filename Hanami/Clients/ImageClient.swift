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
    let prefetchImages: ([URL]) -> Effect<Never, Never>
    let downloadImage: (URL) -> Effect<Result<UIImage, AppError>, Never>
    
    private static let prefetcher = ImagePrefetcher(maxConcurrentRequestCount: 5)
}

extension ImageClient: DependencyKey {
    static var liveValue = ImageClient(
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
                        return promise(.failure(.networkError(URLError(URLError.Code.badURL))))
                    }
                }
            }
            .retry(3)
            .receive(on: DispatchQueue.main)
            .catchToEffect()
        }
    )
    
    static var testValue: ImageClient {
        fatalError("Unimplemented")
    }
}
