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
    private init() { }
    
    public func makeAuth() async -> Result<Void, AppError> {
        let context = LAContext()
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "To unlock the app"
                )
                if success {
                    return .success(())
                } else {
                    return .failure(.authError("Failed to authenticate"))
                }
            } catch let authError as LAError {
                return .failure(.biometryError(authError))
            } catch {
                return .failure(.unknownError(error))
            }
        } else {
            return .success(())
        }
    }
}

extension AuthClient: DependencyKey {
    public static let liveValue = AuthClient()
}
