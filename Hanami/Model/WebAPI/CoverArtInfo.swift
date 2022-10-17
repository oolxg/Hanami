//
//  CoverArt.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation

// MARK: - CoverArt
struct CoverArtInfo: Codable {
    let id: UUID
    let attributes: Attributes
    let relationships: [Relationship]
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let description: String
        let volume: String?
        let fileName, locale: String
        let version: Int
    }
}

extension CoverArtInfo: Equatable {
    static func == (lhs: CoverArtInfo, rhs: CoverArtInfo) -> Bool {
        lhs.id == rhs.id
    }
}

extension CoverArtInfo {
    private var coverArtURLString: String? {
        guard let mangaID = relationships.first(where: { $0.type == .manga })?.id else {
            return nil
        }
        
        let lowercased = mangaID.uuidString.lowercased()
        let fileName = attributes.fileName
        
        return "https://uploads.mangadex.org/covers/\(lowercased)/\(fileName)"
    }
    var coverArtURL: URL? {
        coverArtURLString != nil ? URL(string: coverArtURLString!) : nil
    }
    
    var coverArtURL512: URL? {
        coverArtURLString != nil ? URL(string: coverArtURLString! + ".512.jpg") : nil
    }
    
    var coverArtURL256: URL? {
        coverArtURLString != nil ? URL(string: coverArtURLString! + ".256.jpg") : nil
    }
}
