//
//  ChapterEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 22/05/2022.
//

import Foundation
import ComposableArchitecture

// Example for URL https://api.mangadex.org/chapter/a33906f0-1928-4758-b6fc-f7f079e2dee2
func downloadChapterInfo(chapterID: UUID, decoder: JSONDecoder) -> Effect<Response<ChapterDetails>, APIError> {
    var components = URLComponents()
    
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/chapter/\(chapterID.uuidString.lowercased())"
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .debugDecode(type: Response<ChapterDetails>.self, decoder: decoder)
        .decode(type: Response<ChapterDetails>.self, decoder: decoder)
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

func fetchScanlationGroupInfo(scanlationGroupID: UUID, decoder: JSONDecoder) -> Effect<Response<ScanlationGroup>, APIError> {
    var components = URLComponents()
    
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/group/\(scanlationGroupID.uuidString.lowercased())"
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: Response<ScanlationGroup>.self, decoder: decoder)
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
