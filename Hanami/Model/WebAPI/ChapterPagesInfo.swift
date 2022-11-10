//
//  ChapterPagesInfo.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import Foundation

// MARK: - Chapter
struct ChapterPagesInfo: Decodable {
    let baseURL: String
    let pagesInfo: PagesInfo

    // MARK: - PagesInfo
    struct PagesInfo: Decodable {
        let hash: String
        let dataSaver: [String]
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

extension ChapterPagesInfo {
    var pagesURLs: [URL] {
        pagesInfo.dataSaver.map { fileName in
            URL(string: "\(baseURL)/data-saver/\(pagesInfo.hash)/\(fileName)")!
        }
    }
}
