//
//  Author.swift
//  Hanami
//
//  Created by Oleg on 25/07/2022.
//

import Foundation

struct Author: Codable, Identifiable {
    let id: UUID
    let attributes: Attributes
    let relationships: [Relationship]
    
    struct Attributes: Codable {
        let name: String
        let imageURL: URL?
        let twitter, pixiv, melonBook, fanBox: URL?
        let youtube, weibo, website: URL?
        let version: Int
        
        enum CodingKeys: String, CodingKey {
            case name
            case imageURL = "imageUrl"
            case twitter, pixiv, melonBook, fanBox
            case youtube, weibo, website, version
        }
    }
}


extension Author {
    var name: String {
        attributes.name
    }
}
