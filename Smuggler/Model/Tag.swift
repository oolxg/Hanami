//
//  Tag.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation


// MARK: - Tag
struct Tag: Codable {
    let id: UUID
    let type: String
    let attributes: Attributes
    let relationships: [Relationship]?
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let name: [String: String]
        let group: String
        let version: Int
    }
}
