//
//  CoverArt.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation

// MARK: - CoverArt
struct CoverArt: Codable {
    let id: UUID
    let type: String
    let attributes: Attributes
    let relationships: [Relationship]
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let description: String
        let volume: String?
        let fileName, locale: String
        let createdAt, updatedAt: Date
        let version: Int
    }

    // MARK: - Relationship
    struct Relationship: Codable {
        let id: UUID
        let type: String
    }
}

extension CoverArt: Equatable {
    static func == (lhs: CoverArt, rhs: CoverArt) -> Bool {
        lhs.id == rhs.id
    }
}
