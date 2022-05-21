//
//  Chapter.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation


// MARK: - Chapter
struct Chapter: Codable {
    let attributes: Attributes
    let id: UUID
    let relationships: [Relationship]
    let type: ResponseDataType
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let chapterIndex: Double?
        let createdAt: Date
        let externalURL: URL?
        let pages: Int
        let publishAt: Date
        let readableAt: Date
        let title: String?
        let translatedLanguage: String
        let updatedAt: Date
        let version: Int
        let volume: String?
        
        enum CodingKeys: String, CodingKey {
            case chapterIndex = "chapter"
            case createdAt
            case externalURL = "externalUrl"
            case pages, publishAt, readableAt, title, translatedLanguage, updatedAt, version, volume
        }
    }
}

extension Chapter: Equatable {
    static func ==(lhs: Chapter, rhs: Chapter) -> Bool {
        lhs.id == rhs.id
    }
}

extension Chapter: Identifiable { }

extension Chapter.Attributes {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Chapter.Attributes.CodingKeys.self)
        
        if try container.decode(String?.self, forKey: .chapterIndex) != nil {
            chapterIndex = Double(try container.decode(String?.self, forKey: .chapterIndex)!.replacingOccurrences(of: ",", with: "."))
        } else {
            chapterIndex = nil
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        externalURL = try container.decode(URL?.self, forKey: .externalURL)
        pages = try container.decode(Int.self, forKey: .pages)
        publishAt = try container.decode(Date.self, forKey: .publishAt)
        readableAt = try container.decode(Date.self, forKey: .readableAt)
        title = try container.decode(String?.self, forKey: .title)
        translatedLanguage = try container.decode(String.self, forKey: .translatedLanguage)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        version = try container.decode(Int.self, forKey: .version)
        volume = try container.decode(String?.self, forKey: .volume)
    }
}
