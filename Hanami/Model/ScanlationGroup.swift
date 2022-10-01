//
//  ScanlationGroup.swift
//  Hanami
//
//  Created by Oleg on 13/06/2022.
//

import Foundation


// MARK: - ScanlationGroup
struct ScanlationGroup: Codable {
    let id: UUID
    let attributes: Attributes
    let relationships: [Relationship]
    
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
        let isOfficial, isVerified, isInactive: Bool
        let createdAt, updatedAt: Date
        let version: Int
        
        enum CodingKeys: String, CodingKey {
            case name
            case isLocked = "locked"
            case website
            case discord, contactEmail, description
            case twitter, focusedLanguages
            case isOfficial = "official"
            case isVerified = "verified"
            case isInactive = "inactive"
            case createdAt, updatedAt, version
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
