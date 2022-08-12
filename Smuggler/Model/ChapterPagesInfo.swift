//
//  ChapterPagesInfo.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation

// MARK: - Chapter
struct ChapterPagesInfo: Codable {
    let baseURL: String
    let pagesInfo: PagesInfo

    // MARK: - PagesInfo
    struct PagesInfo: Codable, Equatable {
        let hash: String
        let data, dataSaver: [String]
    }
    
    enum CodingKeys: String, CodingKey {
        case baseURL = "baseUrl"
        case pagesInfo = "chapter"
    }
}

extension ChapterPagesInfo: Equatable {
    static func == (lhs: ChapterPagesInfo, rhs: ChapterPagesInfo) -> Bool {
        lhs.pagesInfo.hash == rhs.pagesInfo.hash
    }
}

extension ChapterPagesInfo: Identifiable {
    var id: String {
        pagesInfo.hash
    }
}

extension ChapterPagesInfo {
    var dataSaverURLs: [URL] {
        pagesInfo.dataSaver.compactMap { fileName in
            URL(string: "\(baseURL)/data-saver/\(pagesInfo.hash)/\(fileName)")
        }
    }
    
    var dataURLs: [URL] {
        pagesInfo.data.compactMap { fileName in
            URL(string: "\(baseURL)/data/\(pagesInfo.hash)/\(fileName)")
        }
    }
}
