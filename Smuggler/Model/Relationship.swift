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
    let type: ResponseDataType
    let related: RelatedType?
    let attributes: RelationshipAttributes?
    
    init(id: UUID, type: ResponseDataType, related: RelatedType? = nil, attributes: RelationshipAttributes? = nil) {
        self.id = id
        self.type = type
        self.related = related
        self.attributes = attributes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ResponseDataType.self, forKey: .type)
        related = try? container.decode(RelatedType?.self, forKey: .related)
        
        do {
            switch type {
                case .coverArt:
                    attributes = .coverArt(try container.decode(CoverArtInfo.Attributes.self, forKey: .attributes))
                case .scanlationGroup:
                    attributes = .scanlationGroup(
                        try container.decode(ScanlationGroup.Attributes.self, forKey: .attributes)
                    )
                case .manga:
                    attributes = .manga(try container.decode(Manga.Attributes.self, forKey: .attributes))
                    
                case .author:
                    attributes = .author(try container.decode(Author.Attributes.self, forKey: .attributes))
                    
                default:
                    attributes = nil
            }
        } catch {
            attributes = nil
        }
    }
    
    // MARK: - RelationshipAttributes
    enum RelationshipAttributes: Codable {
        case coverArt(CoverArtInfo.Attributes)
        case manga(Manga.Attributes)
        case scanlationGroup(ScanlationGroup.Attributes)
        case author(Author.Attributes)
        
        func get() -> Any {
            switch self {
                case .coverArt(let coverArt):
                    return coverArt
                    
                case .manga(let manga):
                    return manga
                    
                case .scanlationGroup(let scanlationGroup):
                    return scanlationGroup
                    
                case .author(let author):
                    return author
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, type, related, attributes
    }

    enum RelatedType: String, Codable {
        case monochrome
        case mainStory = "main_story"
        case adaptedFrom = "adapted_from"
        case basedOn = "based_on"
        case prequel
        case sideStory = "side_story"
        case doujinshi
        case sameFranchise = "same_franchise"
        case sharedUniverse = "shared_universe"
        case sequel
        case spinOff = "spin_off"
        case alternateStory = "alternate_story"
        case alternateVersion = "alternate_version"
        case preserialization, colored, serialization
    }
}

extension Relationship.RelationshipAttributes: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
            case (.coverArt, .coverArt):
                return true
                
            case (.manga, .manga):
                return true
                
            case (.scanlationGroup, .scanlationGroup):
                return true
                
            default:
                return false
        }
    }
}
