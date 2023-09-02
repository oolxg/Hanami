//
//  ImageClient.swift
//  Hanami
//
//  Created by Oleg on 11/08/2022.
//

import Dependencies
import Nuke
import Foundation
import class SwiftUI.UIImage
import Utils

struct ImageClient {
    private let prefetcher: ImagePrefetcher
    
    init(prefetcher: ImagePrefetcher) {
        self.prefetcher = prefetcher
    }

    public func prefetchImages(with urls: [URL]) {
        prefetcher.startPrefetching(with: urls)
    }
    
    public func downloadImage(from url: URL) async throws -> UIImage {
        let data: Data
        
        do {
            data = try await URLSession.shared.data(from: url).0
        } catch {
            let urlError = error as! URLError
            throw AppError.networkError(urlError)
        }
        
        guard let image = UIImage(data: data) else {
            throw AppError.imageError("Failed to decode image.")
        }
        
        return image
    }
}

extension ImageClient: DependencyKey {
    static let liveValue = ImageClient(prefetcher: ImagePrefetcher(destination: .memoryCache, maxConcurrentRequestCount: 5))
}

extension DependencyValues {
    var imageClient: ImageClient {
        get { self[ImageClient.self] }
        set { self[ImageClient.self] = newValue }
    }
}
