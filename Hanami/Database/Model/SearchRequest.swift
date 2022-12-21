//
//  SearchRequest.swift
//  Hanami
//
//  Created by Oleg on 19.12.22.
//

import Foundation

struct SearchRequest: Codable {
    let id: UUID
    let params: SearchParams
    let date: Date
    
    init(id: UUID = UUID(), params: SearchParams, date: Date = .now) {
        self.id = id
        self.params = params
        self.date = date
    }
}

extension SearchRequest: Identifiable { }

extension SearchRequest: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
