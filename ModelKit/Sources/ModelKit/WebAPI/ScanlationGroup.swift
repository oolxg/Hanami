//
//  ScanlationGroup.swift
//  Hanami
//
//  Created by Oleg on 13/06/2022.
//

import Foundation


// MARK: - ScanlationGroup
public struct ScanlationGroup: Decodable {
    public let id: UUID
    public let attributes: Attributes
    public let relationships: [Relationship]
    
    // MARK: - Attributes
    public struct Attributes: Codable {
        public let name: String
        public let isLocked: Bool
        public let website: URL?
        public let discord: URL?
        public let contactEmail: URL?
        public let description: String?
        public let twitter: URL?
        public let focusedLanguages: [String]?
        public let isOfficial, isVerified, isInactive: Bool
        public let createdAt, updatedAt: Date
        public let version: Int
        
        public enum CodingKeys: String, CodingKey {
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
        
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            isLocked = try container.decode(Bool.self, forKey: .isLocked)
            website = URL(string: try container.decodeIfPresent(String.self, forKey: .website) ?? "")
            discord = URL(string: try container.decodeIfPresent(String.self, forKey: .discord) ?? "")
            contactEmail = URL(string: try container.decodeIfPresent(String.self, forKey: .contactEmail) ?? "")
            description = try container.decodeIfPresent(String.self, forKey: .description)
            twitter = URL(string: try container.decodeIfPresent(String.self, forKey: .twitter) ?? "")
            focusedLanguages = try container.decodeIfPresent([String].self, forKey: .focusedLanguages)
            isOfficial = try container.decode(Bool.self, forKey: .isOfficial)
            isVerified = try container.decode(Bool.self, forKey: .isVerified)
            isInactive = try container.decode(Bool.self, forKey: .isInactive)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
            version = try container.decode(Int.self, forKey: .version)
        }
    }
}

extension ScanlationGroup: Equatable {
    public static func == (lhs: ScanlationGroup, rhs: ScanlationGroup) -> Bool {
        lhs.id == rhs.id
    }
}

extension ScanlationGroup: Identifiable { }

public extension ScanlationGroup {
    var name: String {
        attributes.name
    }
}
