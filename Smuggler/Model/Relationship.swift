//
//  Relationship.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation

// MARK: - Relationship
struct Relationship: Codable {
    let id: UUID
    let type: String
    let related: RelationshipType?
    let attributes: RelationshipAttributes?
    
    // MARK: - RelationshipAttributes
    struct RelationshipAttributes: Codable {
        let id: UUID
        let type: String
    }
    
    enum RelationshipType: String, Codable {
        case monochrome, main_story, adapted_from, based_on, prequel
        case side_story, doujinshi, same_franchise, shared_universe, sequel
        case spin_off, alternate_story, alternate_version, preserialization, colored, serialization
    }
}
