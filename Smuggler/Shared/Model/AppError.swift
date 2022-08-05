//
//  AppError.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation

enum AppError: Error {
    case downloadError(URLError)
    case decodingError(DecodingError)
    case unknownError(Error)
    case databaseError(String)
}

extension AppError: Equatable {
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
            case (.downloadError, .downloadError):
                return true
                
            case (.decodingError, .decodingError):
                return true
                
            case (.unknownError, .unknownError):
                return true
                
            case (.databaseError, .databaseError):
                return true
                
            default:
                return false
        }
    }
    
    var description: String {
        switch self {
            case .downloadError(let err):
                return err.localizedDescription
            case .decodingError(let err):
                return err.localizedDescription
            case .unknownError(let err):
                return err.localizedDescription
            case .databaseError(let errorStr):
                return errorStr
        }
    }
}
