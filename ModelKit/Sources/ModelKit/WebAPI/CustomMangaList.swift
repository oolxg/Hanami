//
//  CustomMangaList.swift
//  Hanami
//
//  Created by Oleg on 24/07/2022.
//

import Foundation


// MARK: - CustomMangaList
public struct CustomMangaList: Decodable {
    public let id: UUID
    public let attributes: Attributes
    public let relationships: [Relationship]
    
    // MARK: - Attributes
    public struct Attributes: Decodable {
        public let name: String
        public let visibility: Visibility
        public let version: Int
        
        public enum Visibility: String, Decodable {
            case `public`, `private`
        }
    }
}

extension CustomMangaList: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
