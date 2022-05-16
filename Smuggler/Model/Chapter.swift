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
        let chapter: String?
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
            case chapter, createdAt
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
