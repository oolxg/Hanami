//
//  AppError.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation
import LocalAuthentication
import Kingfisher

public enum AppError: Error {
    case networkError(URLError)
    case JSONDecodingError(DecodingError)
    case unknownError(Error)
    case notFound
    case databaseError(String?)
    case cacheError(String)
    case imageError(String)
    case biometryError(LAError)
    case authError(String)
    case kingfisherError(KingfisherError)
}

extension AppError: Equatable {
    // swiftlint:disable:next cyclomatic_complexity
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError, .networkError):
            return true
            
        case (.notFound, .notFound):
            return true
            
        case (.JSONDecodingError, .JSONDecodingError):
            return true
            
        case (.unknownError, .unknownError):
            return true
            
        case (.databaseError, .databaseError):
            return true
            
        case (.cacheError, .cacheError):
            return true
            
        case (.imageError, .imageError):
            return true
            
        case (.biometryError, .biometryError):
            return true
            
        case (.authError, .authError):
            return true
            
        case (.kingfisherError, .kingfisherError):
            return true
            
        default:
            return false
        }
    }
    // https://stackoverflow.com/a/39481916/11090054
    public var description: String {
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
            
        case .JSONDecodingError:
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
            return errorMessage ?? "Database error"
            
        case .authError(let errorMsg):
            return errorMsg
            
        case .biometryError(let error):
            switch error {
            case LAError.appCancel:
                return "Authentication was cancelled by application"
            case LAError.authenticationFailed:
                return "The user failed to provide valid credentials"
            case LAError.invalidContext:
                return "The context is invalid"
            case LAError.passcodeNotSet:
                return "Passcode is not set on the device"
            case LAError.systemCancel:
                return "Authentication was cancelled by the system"
            case LAError.biometryLockout:
                return "Too many failed attempts."
            case LAError.biometryNotAvailable:
                return "Biometry is not available on the device"
            case LAError.userCancel:
                return "The user did cancel"
            case LAError.userFallback:
                return "The user chose to use the fallback"
            default:
                return "Did not find error code on LAError object"
            }
            
        case .kingfisherError(let kfError):
            return "Kingfisher did thrown an error: \(kfError.localizedDescription)"
        }
    }
}
