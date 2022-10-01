//
//  AppError.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation

enum AppError: Error {
    case networkError(URLError)
    case decodingError(DecodingError)
    case unknownError(Error)
    case notFound
    case databaseError(String)
    case cacheError(String)
    case imageError(String)
}

extension AppError: Equatable {
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
            case (.networkError, .networkError):
                return true
                
            case (.notFound, .notFound):
                return true
                
            case (.decodingError, .decodingError):
                return true
                
            case (.unknownError, .unknownError):
                return true
                
            case (.databaseError, .databaseError):
                return true
                
            case (.cacheError, .cacheError):
                return true
                
            case (.imageError, .imageError):
                return true
                
            default:
                return false
        }
    }
    // https://stackoverflow.com/a/39481916/11090054
    var description: String {
        switch self {
            case .networkError(let err):
                switch err.errorCode {
                    /* NSURLErrorDomain codes */
                    case NSURLErrorUnknown:
                        return "Some network error occured: \(err.localizedDescription)"
                    case NSURLErrorBadURL:
                        return "Something wrong with URL"
                    case NSURLErrorTimedOut:
                        return "Server didn't respond in reasonable time"
                    case NSURLErrorCannotFindHost:
                        return "Can't find given host"
                    case NSURLErrorCannotConnectToHost:
                        return "Can't connect to the given host"
                    case NSURLErrorNetworkConnectionLost:
                        return "Connection with internet was lost"
                    case NSURLErrorResourceUnavailable:
                        return "Requested resource is unavailable at this moment"
                    case NSURLErrorNotConnectedToInternet:
                        return "Device isn't connected to the internet"
                    case NSURLErrorBadServerResponse:
                        return "Some problems on server, try again later"
                    case NSURLErrorUserAuthenticationRequired:
                        return "You must be authenticated to perform this action"
                    case NSURLErrorCannotParseResponse:
                        return "Server returned invalid response"
                        
                    /* Server response codes */
                    case 401:
                        return "You must be authenticated to perform this action"
                    case 403:
                        return "You're not allowed to perform this action"
                    case 404:
                        return "Can't find this page"
                    case 408:
                        return "Request timed out"
                    case 418:
                        return "I'm a teapot"
                    case 429:
                        return "Too many requests, try again a little later"
                    case 451:
                        return "Unavailable for legal reasons"
                    case 500...:
                        return "Some problems on server, try again later"
                    default:
                        return "Some network error occured: \(err.localizedDescription)"
                }
                
            case .decodingError:
                return "Internal error on data decoding"
                
            case .unknownError(let err):
                return "Something strange happened \n\(err.localizedDescription)"
                
            case .notFound:
                return "Requested item not found"
                
            case .cacheError(let errorStr):
                return "Error occured while managing cache: \(errorStr)"
                
            case .imageError(let errorMessage):
                return "Failed to decode image: \(errorMessage)"
                
            case .databaseError(let errorMessage):
                return errorMessage
        }
    }
}
