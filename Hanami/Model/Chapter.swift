//
//  Chapter.swift
//  Smuggler
//
//  Created by mk.pwnz on 22/05/2022.
//

import Foundation

struct Chapter: Codable {
    // sometimes chapters can have number as double, e.g. 77.6 (for extras or oneshots),
    // if chapters has no index(returns 'none'), 'chapterIndex' will be set to -1
    let chapterIndex: Double?
    let id: UUID
    let others: [UUID]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        chapterIndex = Double(try container.decode(String.self, forKey: .chapterIndex))
        id = try container.decode(UUID.self, forKey: .id)
        others = try container.decode([UUID].self, forKey: .others)
    }
    
    enum CodingKeys: String, CodingKey {
        case chapterIndex = "chapter"
        case id, others
    }
}

extension Chapter: Equatable {
    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        lhs.id == rhs.id
    }
}

extension Chapter: Identifiable { }

extension Chapter: Comparable {
    static func < (lhs: Chapter, rhs: Chapter) -> Bool {
        (lhs.chapterIndex ?? -1) > (rhs.chapterIndex ?? -1)
    }
}

extension Chapter {
    init(chapterIndex: Double?, id: UUID, others: [UUID]) {
        self.chapterIndex = chapterIndex
        self.id = id
        self.others = others
    }
}

extension Chapter {
    var chapterName: String {
        chapterIndex == nil ? "Chapter" : "Chapter \(chapterIndex!.clean())"
    }
}
