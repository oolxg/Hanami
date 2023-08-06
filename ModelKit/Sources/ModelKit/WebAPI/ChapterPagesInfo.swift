//
//  ChapterPagesInfo.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import Foundation

// MARK: - Chapter
public struct ChapterPagesInfo: Decodable {
    public let baseURL: String
    public let pagesInfo: PagesInfo

    // MARK: - PagesInfo
    public struct PagesInfo: Decodable {
        public let hash: String
        public let data: [String]
        public let dataSaver: [String]
    }
    
    private enum CodingKeys: String, CodingKey {
        case baseURL = "baseUrl"
        case pagesInfo = "chapter"
    }
}

extension ChapterPagesInfo: Equatable {
    public static func == (lhs: ChapterPagesInfo, rhs: ChapterPagesInfo) -> Bool {
        lhs.pagesInfo.hash == rhs.pagesInfo.hash
    }
}

public extension ChapterPagesInfo {
    func getPagesURLs(highQuality: Bool) -> [URL] {
        highQuality ?
            pagesInfo.data.map { file in URL(string: "\(baseURL)/data/\(pagesInfo.hash)/\(file)")! } :
            pagesInfo.dataSaver.map { file in URL(string: "\(baseURL)/data-saver/\(pagesInfo.hash)/\(file)")! }
    }
}
