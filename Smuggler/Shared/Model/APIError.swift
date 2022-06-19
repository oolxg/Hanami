//
//  APIError.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation

enum APIError: Error {
    case downloadError(URLError)
    case decodingError(DecodingError)
    case unknownError(String)
}

// swiftlint:disable empty_enum_arguments
extension APIError: Equatable {
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
            case (.downloadError(_), .downloadError(_)):
                return true
                
            case (.decodingError(_), .decodingError(_)):
                return true
                
            case (.unknownError(_), .unknownError(_)):
                return true
                
            default:
                return false
        }
    }
}
