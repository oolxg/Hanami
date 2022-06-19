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
            if err is URLError {
                return APIError.downloadError(err as! URLError)
            } else if err is DecodingError {
                return APIError.decodingError(err as! DecodingError)
            }
            
            return APIError.unknownError(err.localizedDescription)
        }
        .eraseToEffect()
}
