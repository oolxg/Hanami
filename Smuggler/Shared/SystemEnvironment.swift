//
//  AppEnvironment.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import ComposableArchitecture


@dynamicMemberLookup
struct SystemEnvironment<Environment> {
    var environment: Environment
    
    subscript<Dependency>(
        dynamicMember keyPath: WritableKeyPath<Environment, Dependency>
    ) -> Dependency {
        get { self.environment[keyPath: keyPath] }
        set { self.environment[keyPath: keyPath] = newValue }
    }
    
    var mainQueue: () -> AnySchedulerOf<DispatchQueue>
    var decoder: () -> JSONDecoder
    
    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss+00:00"

        decoder.dateDecodingStrategy = .formatted(fmt)
        
        return decoder
    }
    
    static func live(environment: Environment) -> Self {
        Self(environment: environment, mainQueue: { .main }, decoder: decoder)
    }
    
    static func dev(environment: Environment) -> Self {
        Self(environment: environment, mainQueue: { .main }, decoder: decoder)
    }
}

