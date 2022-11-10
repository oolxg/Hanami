//
//  CustomMangaList.swift
//  Hanami
//
//  Created by Oleg on 24/07/2022.
//

import Foundation


// MARK: - CustomMangaList
struct CustomMangaList: Decodable {
    let id: UUID
    let attributes: Attributes
    let relationships: [Relationship]
    
    // MARK: - Attributes
    struct Attributes: Decodable {
        let name: String
        let visibility: Visibility
        let version: Int
        
        enum Visibility: String, Decodable {
            case `public`, `private`
        }
    }
}

extension CustomMangaList: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
