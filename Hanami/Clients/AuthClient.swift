//
//  AuthClient.swift
//  Hanami
//
//  Created by Oleg on 13/10/2022.
//

import Foundation
import ComposableArchitecture
import Combine
import LocalAuthentication

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

struct AuthClient {
    let makeAuth: () -> Effect<Result<Void, AppError>, Never>
}

extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
        makeAuth: {
            Future { promise in
                let scanner = LAContext()
                
                scanner.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "To unlock the app"
                ) { success, error in
                    if success {
                        return promise(.success(()))
                    } else if let error = error as? LAError {
                        return promise(.failure(.biometryError(error)))
                    } else {
                        return promise(.failure(.unknownError(error!)))
                    }
                }
            }
            .catchToEffect()
        }
    )
}
