//
//  ChapterDetails.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation

// https://api.mangadex.org/chapter?manga=9a9bbd35-a923-494e-855f-2ffe60992dc6&limit=11
// JSON Response example
/*
{
    "result":"ok",
    "response":"entity",
    "data":{
        "id":"c280a6cc-d2d6-4e00-91c4-1481b7494e21",
        "type":"chapter",
        "attributes":{
            "volume":"1",
            "chapter":"4",
            "title":"",
            "translatedLanguage":"en",
            "externalUrl":null,
            "publishAt":"2018-01-22T05:58:20+00:00",
            "readableAt":"2018-01-22T05:58:20+00:00",
            "createdAt":"2018-01-22T05:58:20+00:00",
            "updatedAt":"2018-01-22T05:58:20+00:00",
            "pages":22,
            "version":1
        },
        "relationships":[
            {
            "id":"35a7f8c8-d1a5-4feb-b18b-294b221e53a6",
            "type":"scanlation_group"
            },
            {
            "id":"9a9bbd35-a923-494e-855f-2ffe60992dc6",
            "type":"manga"
            },
            {
            "id":"78559d93-a8ff-41b0-8b66-109e9ce64f95",
            "type":"user"
            }
        ]
    }
}
*/

// MARK: - Chapter
struct ChapterDetails: Codable {
    let attributes: Attributes
    let id: UUID
    let relationships: [Relationship]
    let type: ResponseDataType
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let chapterIndex: Double?
        let createdAt: Date
        let externalURL: URL?
        let pagesCount: Int
        let publishAt: Date
        let readableAt: Date
        let title: String?
        let translatedLanguage: String
        let updatedAt: Date
        let version: Int
        let volumeIndex: String?
        
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case chapterIndex = "chapter"
            case createdAt
            case externalURL = "externalUrl"
            case pagesCount = "pages"
            case publishAt, readableAt, title, translatedLanguage, updatedAt, version
            case volumeIndex = "volume"
        }
    }
}

extension ChapterDetails: Equatable {
    static func == (lhs: ChapterDetails, rhs: ChapterDetails) -> Bool {
        lhs.id == rhs.id
    }
}

extension ChapterDetails: Identifiable { }

extension ChapterDetails.Attributes {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ChapterDetails.Attributes.CodingKeys.self)
        
        if try container.decode(String?.self, forKey: .chapterIndex) != nil {
            chapterIndex = Double(try container.decode(
                String?.self,
                forKey: .chapterIndex
            // swiftlint:disable:next multiline_function_chains
            )!.replacingOccurrences(of: ",", with: "."))
        } else {
            chapterIndex = nil
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        externalURL = try container.decode(URL?.self, forKey: .externalURL)
        pagesCount = try container.decode(Int.self, forKey: .pagesCount)
        publishAt = try container.decode(Date.self, forKey: .publishAt)
        readableAt = try container.decode(Date.self, forKey: .readableAt)
        let tempTitle = try container.decode(String?.self, forKey: .title)
        // this also disable because tempTitle is Optional
        // swiftlint:disable:next empty_string
        title = tempTitle == "" ? nil : tempTitle
        translatedLanguage = try container.decode(String.self, forKey: .translatedLanguage)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        version = try container.decode(Int.self, forKey: .version)
        volumeIndex = try container.decode(String?.self, forKey: .volumeIndex)
    }
}

extension ChapterDetails {
    var languageFlag: String {
        let flags = [
            "ar": "🇸🇦",
            "de": "🇩🇪",
            "en": "🇬🇧",
            "es": "🇪🇸",
            "es-la": "🇲🇽",
            "fr": "🇫🇷",
            "id": "🇮🇩",
            "it": "🇮🇹",
            "ja": "🇯🇵",
            "ja-ro": "🇯🇵",
            "pl": "🇵🇱",
            "pt": "🇵🇹",
            "pt-br": "🇧🇷",
            "ru": "🇷🇺",
            "tr": "🇹🇷",
            "th": "🇹🇭",
            "uk": "🇺🇦",
            "vi": "🇻🇳",
            "zh": "🇨🇳",
            "zh-hk": "🇨🇳",
            "zh-ro": "🇨🇳"
        ]
        
        return flags[attributes.translatedLanguage] ?? "❓"
    }
    
    var chapterName: String {
        if let title = attributes.title {
            return attributes.chapterIndex?.clean == nil ?
            "\(languageFlag) \(title)" :
            "\(languageFlag) Ch. \(attributes.chapterIndex!.clean) - \(title)"
        } else if let index = attributes.chapterIndex?.clean {
            return "\(languageFlag) Ch. \(index)"
        } else if attributes.pagesCount == 1 {
            return "Oneshot"
        } else {
            return "Chapter"
        }
    }
    
    var scanltaionGroupID: UUID? {
        relationships.first { $0.type == .scanlationGroup }?.id
    }
}
