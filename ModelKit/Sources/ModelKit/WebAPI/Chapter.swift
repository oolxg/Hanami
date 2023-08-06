//
//  Chapter.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import Foundation
import DataTypeExtensions

public struct Chapter: Decodable {
    // sometimes chapters can have number as double, e.g. 77.6 (for extras or oneshots),
    public let index: Double?
    public let id: UUID
    public let others: [UUID]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        index = Double(try container.decode(String.self, forKey: .index))
        id = try container.decode(UUID.self, forKey: .id)
        others = try container.decode([UUID].self, forKey: .others)
    }
    
    enum CodingKeys: String, CodingKey {
        case index = "chapter"
        case id, others
    }
}

extension Chapter: Equatable {
    public static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        lhs.id == rhs.id
    }
}

extension Chapter: Identifiable { }

public extension Chapter {
    init(index: Double?, id: UUID, others: [UUID]) {
        self.index = index
        self.id = id
        self.others = others
    }
}

public extension Chapter {
    var chapterName: String {
        index.isNil ? "Chapter" : "Chapter \(index!.clean())"
    }
}
