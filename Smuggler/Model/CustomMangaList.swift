//
//  CustomMangaList.swift
//  Smuggler
//
//  Created by mk.pwnz on 24/07/2022.
//

import Foundation

// swiftlint:disable nesting

// MARK: - CustomMangaList
struct CustomMangaList: Codable {
    let id: UUID
    let type: ResponseDataType
    let attributes: Attributes
    let relationships: [Relationship]
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let name: String
        let visibility: Visibility
        let version: Int
        
        enum Visibility: String, Codable {
            case `public`, `private`
        }
    }
}

extension CustomMangaList: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
