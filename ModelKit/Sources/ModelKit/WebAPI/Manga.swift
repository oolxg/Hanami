//
//  Manga.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation
import SwiftUI

// MARK: - Manga
public struct Manga: Decodable {
    public let id: UUID
    public let attributes: Attributes
    public let relationships: [Relationship]
    
    // MARK: - Attributes
    public struct Attributes: Codable {
        public let title: LocalizedString
        public let altTitles: LocalizedString
        public let description: LocalizedString
        public let isLocked: Bool
        public let originalLanguage: String
        public let status: Status
        public let contentRating: ContentRatings
        public let tags: [Tag]
        public let state: State
        
        public let createdAt: Date?
        public let updatedAt: Date?
        public let lastVolume: String?
        public let lastChapter: String?
        public let publicationDemographic: PublicationDemographic?
        public let year: Int?
        
        public enum CodingKeys: String, CodingKey {
            case title, altTitles
            case description, isLocked, originalLanguage, lastVolume, lastChapter, publicationDemographic, status
            case year, contentRating, tags, state, createdAt, updatedAt
        }
        
        public enum Status: String, Codable {
            case completed, ongoing, cancelled, hiatus
        }
        
        public enum PublicationDemographic: String, Codable {
            case shounen, shoujo, josei, seinen
        }
        
        public enum ContentRatings: String, Codable {
            case safe, suggestive, erotica, pornographic
        }
        
        public enum State: String, Codable {
            case draft, submitted, published, rejected
        }
    }
    
    public init(id: UUID, attributes: Attributes, relationships: [Relationship]) {
        self.id = id
        self.attributes = attributes
        self.relationships = relationships
    }
}

// MARK: - Custom init for fucked up MangaDex API
public extension Manga.Attributes {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(LocalizedString.self, forKey: .title)
        do {
            altTitles = try container.decode(LocalizedString.self, forKey: .altTitles)
        } catch {
            let altTitlesDicts = try container.decode([LocalizedString].self, forKey: .altTitles)
            altTitles = LocalizedString(localizedStrings: altTitlesDicts)
        }
        do {
            description = try container.decode(LocalizedString.self, forKey: .description)
        } catch DecodingError.typeMismatch {
            let descriptions = try container.decode([LocalizedString].self, forKey: .description)
            description = LocalizedString(localizedStrings: descriptions)
        }
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        originalLanguage = try container.decode(String.self, forKey: .originalLanguage)
        lastVolume = try container.decodeIfPresent(String.self, forKey: .lastVolume)
        lastChapter = try container.decodeIfPresent(String.self, forKey: .lastChapter)
        publicationDemographic = try container.decodeIfPresent(
            PublicationDemographic.self, forKey: .publicationDemographic
        )
        status = try container.decode(Status.self, forKey: .status)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        contentRating = try container.decode(ContentRatings.self, forKey: .contentRating)
        tags = try container.decode([Tag].self, forKey: .tags)
        state = try container.decode(State.self, forKey: .state)
        
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

extension Manga: Equatable {
    public static func == (lhs: Manga, rhs: Manga) -> Bool {
        lhs.id == rhs.id
    }
}

public extension Manga {
    var title: String {
        if let title = attributes.title.availableText {
            return title
        } else {
            return attributes.altTitles.availableText ?? "No title available"
        }
    }
    
    var description: String? {
        attributes.description.availableText
    }
    
    var authors: [Author] {
        relationships
            .filter { $0.type == .author }
            .compactMap {
                guard let attrs = $0.attributes?.value as? Author.Attributes else {
                    return nil
                }
                
                return Author(id: $0.id, attributes: attrs, relationships: [
                    Relationship(id: self.id, type: .manga)
                ])
            }
    }
    
    var coverArtInfo: CoverArtInfo? {
        if let relationship = relationships.first(where: { $0.type == .coverArt }),
           let attributes = relationship.attributes?.value as? CoverArtInfo.Attributes {
            return CoverArtInfo(
                id: relationship.id, attributes: attributes, relationships: [
                    Relationship(id: self.id, type: .manga)
                ]
            )
        }
        
        return nil
    }
    
    var coverArtID: UUID? {
        relationships.first(where: { $0.type == .coverArt })?.id
    }
}

extension Tag: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct CoreDataMangaEntry: Decodable {
    public let manga: Manga
    public let addedAt: Date
    
    public init(manga: Manga, addedAt: Date) {
        self.manga = manga
        self.addedAt = addedAt
    }
}

extension CoreDataMangaEntry: Identifiable {
    public var id: UUID { manga.id }
}

extension CoreDataMangaEntry: Equatable { }

public extension Manga.Attributes.Status {
    var color: Color {
        switch self {
        case .completed:
            return .blue
        case .ongoing:
            return .green
        case .cancelled:
            return .red
        case .hiatus:
            return .red
        }
    }
}
