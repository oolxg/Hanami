//
//  MangaThumbnailEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation
import ComposableArchitecture


func downloadThumbnailInfo(coverID: UUID?, decoder: JSONDecoder) -> Effect<Response<CoverArt>, APIError> {
    guard let coverID = coverID, let url = URL(string: "https://api.mangadex.org/cover/\(coverID.uuidString.lowercased())") else {
        return .none
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .mapError { _ in APIError.downloadError }
        .map { data, _ in data }
        .decode(type: Response<CoverArt>.self, decoder: decoder)
        .mapError { _ in APIError.decodingError }
        .eraseToEffect()
}

