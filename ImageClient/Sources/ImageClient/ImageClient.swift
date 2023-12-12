import Dependencies
import UIKit
import Kingfisher
import Foundation
import Utils

public struct ImageClient {
    private init() { }
    
    public func prefetchImages(with urls: [URL]) {
        ImagePrefetcher(
            urls: urls,
            options: [
                .alsoPrefetchToMemory,
                .backgroundDecode
            ]
        ).start()
    }
    
    public func downloadImage(from url: URL) async -> Result<UIImage, AppError> {
        await withCheckedContinuation { continuation in
            KingfisherManager.shared.retrieveImage(with: url) { result in
                switch result {
                case .success(let value):
                    let data = value.image.pngData()
                    
                    if let data, let image = UIImage(data: data) {
                        continuation.resume(returning: .success(image))
                        return
                    }
                    
                    continuation.resume(returning: .failure(.imageError("Can't decode image")))
                    
                case .failure(let error):
                    continuation.resume(returning: .failure(AppError.kingfisherError(error)))
                }
            }
        }
    }
    
    public func clearCache() {
        Task {
            try? KingfisherManager.shared.cache.diskStorage.removeAll()
            KingfisherManager.shared.cache.memoryStorage.removeAll()
        }
    }
}

extension ImageClient: DependencyKey {
    public static let liveValue = {
        ImageClient()
    }()
}

public extension DependencyValues {
    var imageClient: ImageClient {
        get { self[ImageClient.self] }
        set { self[ImageClient.self] = newValue }
    }
}
