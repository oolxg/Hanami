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
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: Response<CoverArtInfo>.self, decoder: decoder)
        .mapError { err -> APIError in
            if let err = err as? URLError {
                return APIError.downloadError(err)
            } else if let err = err as? DecodingError {
                return APIError.decodingError(err)
            }
            
            return APIError.unknownError(err)
        }
        .eraseToEffect()
}
