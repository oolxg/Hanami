//
//  MangaThumbnailEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

func downloadThumbnailInfo(coverID: UUID) -> Effect<Response<CoverArtInfo>, AppError> {
    guard let url = URL(string: "https://api.mangadex.org/cover/\(coverID.uuidString.lowercased())") else {
        return .none
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: Response<CoverArtInfo>.self, decoder: AppUtil.decoder)
        .mapError { err -> AppError in
            if let err = err as? URLError {
                return AppError.downloadError(err)
            } else if let err = err as? DecodingError {
                return AppError.decodingError(err)
            }
            
            return AppError.unknownError(err)
        }
        .eraseToEffect()
}
