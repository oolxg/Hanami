//
//  CoverArt.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation

// MARK: - CoverArt
struct CoverArtInfo: Codable {
    let id: UUID
    let type: ResponseDataType
    let attributes: Attributes
    let relationships: [Relationship]
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let description: String
        let volume: String?
        let fileName, locale: String
        let createdAt, updatedAt: Date
        let version: Int
    }

    // MARK: - Relationship
    struct Relationship: Codable {
        let id: UUID
        let type: ResponseDataType
    }
}

extension CoverArtInfo: Equatable {
    static func == (lhs: CoverArtInfo, rhs: CoverArtInfo) -> Bool {
        lhs.id == rhs.id
    }
}

extension CoverArtInfo {
    private var coverArtString: String? {
        guard let mangaID = relationships.first(where: { $0.type == .manga })?.id else {
            return nil
        }
        
        let lowercased = mangaID.uuidString.lowercased()
        let fileName = attributes.fileName
        
        return "https://uploads.mangadex.org/covers/\(lowercased)/\(fileName)"
    }
    var coverArtURL: URL? {
        coverArtString != nil ? URL(string: coverArtString!) : nil
    }
    
    var coverArtURL512: URL? {
        coverArtString != nil ? URL(string: coverArtString! + ".512.jpg") : nil
    }
    
    var coverArtURL256: URL? {
        coverArtString != nil ? URL(string: coverArtString! + ".256.jpg") : nil
    }
}
