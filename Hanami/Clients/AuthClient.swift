//
//  AuthClient.swift
//  Hanami
//
//  Created by Oleg on 13/10/2022.
//

import ComposableArchitecture
import Combine
import LocalAuthentication
import Foundation

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

struct AuthClient {
    let makeAuth: () -> EffectTask<Result<Void, AppError>>
}

extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
        makeAuth: {
            Future { promise in
                let context = LAContext()
                
                var error: NSError?
                
                if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                    context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: "To unlock the app"
                    ) { success, authError in
                        if success {
                            return promise(.success(()))
                        } else if let authError = authError as? LAError {
                            return promise(.failure(.biometryError(authError)))
                        } else if let authError {
                            return promise(.failure(.unknownError(authError)))
                        } else {
                            return promise(.failure(.authError("User closed the app")))
                        }
                    }
                } else if let error = error as? LAError {
                    if error.code == .biometryNotAvailable {
                        // we will return success because user turned off Biometry Auth
                        return promise(.success(()))
                    }
                    return promise(.failure(.biometryError(error)))
                } else {
                    // ???
                    return promise(.success(()))
                }
            }
            .catchToEffect()
        }
    )
}
