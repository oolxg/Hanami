import Dependencies
import Kingfisher
import Foundation
import class SwiftUI.UIImage
import Utils

public struct ImageClient {
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
        let data: Data
        
        do {
            data = try await URLSession.shared.data(from: url).0
        } catch {
            if let urlError = error as? URLError {
                return .failure(AppError.networkError(urlError))
            } else {
                return .failure(AppError.unknownError(error))
            }
        }
        
        guard let image = UIImage(data: data) else {
            return .failure(AppError.imageError("Failed to decode image."))
        }
        
        return .success(image)
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
