//
//  NullCodable.swift
//  Smuggler
//
//  Created by g-mark
//  https://github.com/g-mark/NullCodable/blob/master/Sources/NullCodable/NullCodable.swift
//

import Foundation

@propertyWrapper
public struct NullCodable<Wrapped> {
    public var wrappedValue: Wrapped?
    
    public init(wrappedValue: Wrapped?) {
        self.wrappedValue = wrappedValue
    }
}

extension NullCodable: Encodable where Wrapped: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch wrappedValue {
            case .some(let value): try container.encode(value)
            case .none: try container.encodeNil()
        }
    }
}

extension NullCodable: Decodable where Wrapped: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            wrappedValue = try container.decode(Wrapped.self)
        }
    }
}

extension NullCodable: Equatable where Wrapped: Equatable { }

extension KeyedDecodingContainer {
    public func decode<Wrapped>(
        _ type: NullCodable<Wrapped>.Type,
        forKey key: KeyedDecodingContainer<K>.Key
    ) throws -> NullCodable<Wrapped> where Wrapped: Decodable {
        try decodeIfPresent(NullCodable<Wrapped>.self, forKey: key) ?? NullCodable<Wrapped>(wrappedValue: nil)
    }
}
