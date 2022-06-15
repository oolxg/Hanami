//
//  ScanlationGroup.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/06/2022.
//

import Foundation

// swiftlint:disable nesting

// MARK: - ScanlationGroup
struct ScanlationGroup: Codable {
    let id: UUID
    let type: ResponseDataType
    let attributes: Attributes
    let relationships: [ScanlationGroupRelationship]
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let name: String
        let isLocked: Bool
        let website: URL?
        let discord: URL?
        let contactEmail: URL?
        let description: String?
        let twitter: URL?
        let focusedLanguages: [String]?
        let official, verified, inactive: Bool
        let createdAt, updatedAt: Date
        let version: Int
        
        enum CodingKeys: String, CodingKey {
            case name
            case isLocked = "locked"
            case website
            case discord, contactEmail, description
            case twitter, focusedLanguages
            case official, verified, inactive
            case createdAt, updatedAt, version
        }
    }
    
    struct ScanlationGroupRelationship: Codable {
        let id: UUID
        let type: ScanlationGroupRelationshipType
        
        enum ScanlationGroupRelationshipType: String, Codable {
            case member, leader
        }
    }
}

extension ScanlationGroup: Equatable {
    static func == (lhs: ScanlationGroup, rhs: ScanlationGroup) -> Bool {
        lhs.id == rhs.id
    }
}

extension ScanlationGroup: Identifiable { }

extension ScanlationGroup {
    var name: String {
        attributes.name
    }
}
