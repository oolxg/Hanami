//
//  Relationship.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation

// MARK: - Relationship
struct Relationship: Codable {
    let id: UUID
    let type: ResponseDataType
    let related: RelatedType?
    let attributes: Attributes?
    
    init(id: UUID, type: ResponseDataType, related: RelatedType? = nil, attributes: Attributes? = nil) {
        self.id = id
        self.type = type
        self.related = related
        self.attributes = attributes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ResponseDataType.self, forKey: .type)
        related = try container.decodeIfPresent(RelatedType.self, forKey: .related)
        
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(related, forKey: .related)
        switch attributes {
            case .coverArt(let coverArt):
                try container.encode(coverArt, forKey: .attributes)

            case .manga(let manga):
                try container.encode(manga, forKey: .attributes)

            case .scanlationGroup(let scanlationGroup):
                try container.encode(scanlationGroup, forKey: .attributes)

            case .author(let author):
                try container.encode(author, forKey: .attributes)
                
            case .none:
                break
        }
    }
    
    // MARK: - RelationshipAttributes
    enum Attributes: Codable {
        case coverArt(CoverArtInfo.Attributes)
        case manga(Manga.Attributes)
        case scanlationGroup(ScanlationGroup.Attributes)
        case author(Author.Attributes)
        
        var value: Any {
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
