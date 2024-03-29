//
//  ChapterDetails.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import Foundation

// MARK: - Chapter
public struct ChapterDetails: Decodable {
    public let attributes: Attributes
    public let id: UUID
    public let relationships: [Relationship]
    
    // MARK: - Attributes
    public struct Attributes: Codable {
        public let createdAt: Date
        public let pagesCount: Int
        public let publishAt: Date
        public let translatedLanguage: String?
        public let updatedAt: Date
        public let version: Int

        public let index: Double?
        public let externalURL: URL?
        public let readableAt: Date?
        public let title: String?
        public let volumeIndex: Double?
        
        public enum CodingKeys: String, CodingKey {
            case index = "chapter"
            case createdAt
            case externalURL = "externalUrl"
            case pagesCount = "pages"
            case publishAt, readableAt, title, translatedLanguage, updatedAt, version
            case volumeIndex = "volume"
        }
    }
    
    public init(attributes: Attributes, id: UUID, relationships: [Relationship]) {
        self.attributes = attributes
        self.id = id
        self.relationships = relationships
    }
}

extension ChapterDetails: Equatable {
    public static func == (lhs: ChapterDetails, rhs: ChapterDetails) -> Bool {
        lhs.id == rhs.id
    }
}

extension ChapterDetails: Identifiable { }

extension ChapterDetails.Attributes {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ChapterDetails.Attributes.CodingKeys.self)
        
        // this needed because we get `chapterIndex` as String from MangaDex API, but we use it and save it as Double
        do {
            let chapterIndexString = try container.decode(String.self, forKey: .index)
            index = Double(chapterIndexString.replacingOccurrences(of: ",", with: "."))
        } catch {
            index = try? container.decode(Double?.self, forKey: .index)
        }
        
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        externalURL = try container.decodeIfPresent(URL.self, forKey: .externalURL)
        pagesCount = try container.decode(Int.self, forKey: .pagesCount)
        publishAt = try container.decode(Date.self, forKey: .publishAt)
        readableAt = try container.decodeIfPresent(Date.self, forKey: .readableAt)
        let tempTitle = try container.decodeIfPresent(String.self, forKey: .title)
        // swiftlint:disable:next empty_string
        title = tempTitle == "" ? nil : tempTitle
        translatedLanguage = try container.decodeIfPresent(String.self, forKey: .translatedLanguage)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        version = try container.decode(Int.self, forKey: .version)
        
        if let volumeIndexString = try? container.decode(String.self, forKey: .volumeIndex) {
            volumeIndex = Double(volumeIndexString)
        } else {
            volumeIndex = try? container.decode(Double.self, forKey: .volumeIndex)
        }
    }
}

public extension ChapterDetails {
    var languageFlag: String {
        let flags = [
            "ar": "🇸🇦",
            "cs": "🇨🇿",
            "de": "🇩🇪",
            "en": "🇬🇧",
            "es": "🇪🇸",
            "es-la": "🇲🇽",
            "fa": "🇮🇷", // farsi
            "fr": "🇫🇷",
            "hi": "🇮🇳", // hindi
            "hu": "🇭🇺",
            "id": "🇮🇩",
            "it": "🇮🇹",
            "ja": "🇯🇵",
            "ja-ro": "🇯🇵",
            "mn": "🇲🇳", // mongolian
            "ms": "🇲🇾",
            "nl": "🇳🇱",
            "pl": "🇵🇱",
            "pt": "🇵🇹",
            "pt-br": "🇧🇷",
            "ru": "🇷🇺",
            "tr": "🇹🇷",
            "th": "🇹🇭",
            "uk": "🇺🇦",
            "vi": "🇻🇳",
            "zh": "🇨🇳",
            "zh-hk": "🇨🇳",
            "zh-ro": "🇨🇳"
        ]
        
        if let translatedLanguage = attributes.translatedLanguage {
            return flags[translatedLanguage, default: "❓"]
        }
        
        return "❓"
    }
    
    var chapterName: String {
        if let title = attributes.title {
            return "\(languageFlag) \(title)"
        } else if let index = attributes.index?.clean() {
            return "\(languageFlag) Ch. \(index)"
        } else if attributes.pagesCount == 1 {
            return "Oneshot"
        } else {
            return "Chapter"
        }
    }
    
    var asChapter: Chapter {
        Chapter(index: attributes.index, id: id, others: [])
    }
    
    var scanlationGroupID: UUID? {
        relationships.first { $0.type == .scanlationGroup }?.id
    }
    
    var scanlationGroup: ScanlationGroup? {
        relationships
            .filter { $0.type == .scanlationGroup }
            .compactMap {
                guard let attrs = $0.attributes?.value as? ScanlationGroup.Attributes else {
                    return nil
                }
                
                return ScanlationGroup(id: $0.id, attributes: attrs, relationships: [])
            }
            .first
    }
}
