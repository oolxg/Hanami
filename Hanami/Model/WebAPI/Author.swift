//
//  Author.swift
//  Hanami
//
//  Created by Oleg on 25/07/2022.
//

import Foundation

struct Author: Decodable {
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
            do {
                biography = try container.decode(LocalizedString.self, forKey: .biography)
            } catch {
                let biographyDict = try container.decode([LocalizedString].self, forKey: .biography)
                biography = LocalizedString(localizedStrings: biographyDict)
            }
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

extension Manga: Identifiable { }

extension Author {
    init(id: UUID, attributes: Author.Attributes, relationship: [Relationship]) {
        self.id = id
        self.attributes = attributes
        self.relationships = relationship
    }
}

extension Author.Attributes {
    init(name: String, imageURL: URL?, biography: LocalizedString?, twitter: URL?, pixiv: URL?, melonBook: URL?, fanBox: URL?, youtube: URL?, weibo: URL?, website: URL?, version: Int) {
        self.name = name
        self.imageURL = imageURL
        self.biography = biography
        self.twitter = twitter
        self.pixiv = pixiv
        self.melonBook = melonBook
        self.fanBox = fanBox
        self.youtube = youtube
        self.weibo = weibo
        self.website = website
        self.version = version
    }
}

extension Author: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

extension Author: Equatable {
    static func == (lhs: Author, rhs: Author) -> Bool {
        lhs.id == rhs.id
    }
}

extension Author {
    var mangaIDs: [UUID] {
        relationships.filter { $0.type == .manga }.map(\.id)
    }
}
