//
//  ScanlationGroup.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/06/2022.
//

import Foundation


// MARK: - ScanlationGroup
struct ScanlationGroup: Codable {
    let id: UUID
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
    
    struct ScanlationGroupRelationship: Codable {
        let id: UUID
        let type: ScanlationGroupRelationshipType
        
        enum ScanlationGroupRelationshipType: String, Codable {
            case member, leader
        }
    }
}

extension ScanlationGroup.Attributes {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        
        website = try? container.decode(URL?.self, forKey: .website)
        discord = try? container.decode(URL?.self, forKey: .discord)
        contactEmail = try? container.decode(URL?.self, forKey: .contactEmail)
        description = try container.decode(String?.self, forKey: .description)
        twitter = try? container.decode(URL?.self, forKey: .twitter)
        focusedLanguages = try container.decode([String]?.self, forKey: .focusedLanguages)
        isOfficial = try container.decode(Bool.self, forKey: .isOfficial)
        isVerified = try container.decode(Bool.self, forKey: .isVerified)
        isInactive = try container.decode(Bool.self, forKey: .isInactive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        version = try container.decode(Int.self, forKey: .version)
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
