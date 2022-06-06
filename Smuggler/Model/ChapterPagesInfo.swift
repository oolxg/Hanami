//
//  ChapterPagesInfo.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation

// MARK: - Chapter
struct ChapterPagesInfo: Codable {
    let result: String
    let baseURL: String
    let chapter: ChapterInfo

    // MARK: - ChapterInfo
    struct ChapterInfo: Codable, Equatable {
        let hash: String
        let data, dataSaver: [String]
    }
    
    enum CodingKeys: String, CodingKey {
        case result
        case baseURL = "baseUrl"
        case chapter
    }
}

extension ChapterPagesInfo: Equatable { }

extension ChapterPagesInfo: Identifiable {
    var id: String {
        chapter.hash
    }
}
