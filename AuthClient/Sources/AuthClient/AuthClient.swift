//
//  AuthClient.swift
//  Hanami
//
//  Created by Oleg on 13/10/2022.
//

import Dependencies
import Combine
import LocalAuthentication
import Foundation
import Utils

public extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

public struct AuthClient {
    public func makeAuth() async throws -> Bool {
        let context = LAContext()
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "To unlock the app"
                )
                return success
            } catch let authError as LAError {
                throw AppError.biometryError(authError)
            } catch {
                throw AppError.unknownError(error)
            }
        } else {
            return true
        }
    }
}

extension AuthClient: DependencyKey {
    public static let liveValue = AuthClient()
}
