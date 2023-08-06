//
//  CoverArt.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation

// MARK: - CoverArt
public struct CoverArtInfo: Codable {
    public let id: UUID
    public let attributes: Attributes
    public let relationships: [Relationship]
    
    // MARK: - Attributes
    public struct Attributes: Codable {
        public let description: String
        public let volume: String?
        public let fileName, locale: String
        public let version: Int
    }
}

extension CoverArtInfo: Equatable {
    public static func == (lhs: CoverArtInfo, rhs: CoverArtInfo) -> Bool {
        lhs.id == rhs.id
    }
}

public extension CoverArtInfo {
    private var coverArtURLString: String? {
        guard let mangaID = relationships.first(where: { $0.type == .manga })?.id else {
            return nil
        }
        
        let lowercased = mangaID.uuidString.lowercased()
        let fileName = attributes.fileName
        
        return "https://uploads.mangadex.org/covers/\(lowercased)/\(fileName)"
    }
    
    var coverArtURL: URL? {
        coverArtURLString.hasValue ? URL(string: coverArtURLString!) : nil
    }
    
    var coverArtURL512: URL? {
        coverArtURLString.hasValue ? URL(string: coverArtURLString! + ".512.jpg") : nil
    }
    
    var coverArtURL256: URL? {
        coverArtURLString.hasValue ? URL(string: coverArtURLString! + ".256.jpg") : nil
    }
}
