//
//  MangaThumbnailEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

func downloadThumbnailInfo(coverID: UUID, decoder: JSONDecoder) -> Effect<Response<CoverArtInfo>, APIError> {
    guard let url = URL(string: "https://api.mangadex.org/cover/\(coverID.uuidString.lowercased())") else {
        return .none
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { _ in APIError.downloadError }
        .retry(3)
        .map { data, _ in data }
        .decode(type: Response<CoverArtInfo>.self, decoder: decoder)
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}
