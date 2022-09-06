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
        let biography: LocalizedString?
        let twitter, pixiv, melonBook, fanBox: URL?
        let youtube, weibo, website: URL?
        let version: Int
        
        enum CodingKeys: String, CodingKey {
            case name
            case imageURL = "imageUrl"
            case biography, twitter, pixiv, melonBook, fanBox
            case youtube, weibo, website, version
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            name = try container.decode(String.self, forKey: .name)
            imageURL = try? container.decode(URL.self, forKey: .imageURL)
            biography = try? container.decode(LocalizedString.self, forKey: .biography)
            twitter = try? container.decode(URL.self, forKey: .twitter)
            pixiv = try? container.decode(URL.self, forKey: .pixiv)
            melonBook = try? container.decode(URL.self, forKey: .melonBook)
            fanBox = try? container.decode(URL.self, forKey: .fanBox)
            youtube = try? container.decode(URL.self, forKey: .youtube)
            weibo = try? container.decode(URL.self, forKey: .weibo)
            website = try? container.decode(URL.self, forKey: .website)
            version = try container.decode(Int.self, forKey: .version)
        }
    }
}


extension Author {
    var name: String {
        attributes.name
    }
}
