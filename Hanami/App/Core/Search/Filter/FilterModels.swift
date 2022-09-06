//
//  FilterModels.swift
//  Hanami
//
//  Created by Oleg on 04/06/2022.
//

import Foundation

enum TagState {
    case selected, notSelected, banned
}

protocol FilterTagProtocol: Identifiable, Equatable {
    var state: TagState { get set }
    var name: String { get }
}

extension FilterTagProtocol {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.state == rhs.state
    }
}

struct FilterTag: FilterTagProtocol, Comparable {
    let tag: Tag
    var name: String {
        tag.name
    }
    var state: TagState = .notSelected
    var type: Tag.Attributes.Group { tag.attributes.group }
    var id: UUID { tag.id }
    
    static func < (lhs: FilterTag, rhs: FilterTag) -> Bool {
        lhs.tag.attributes.name.en.rawValue < rhs.tag.attributes.name.en.rawValue
    }
    
    mutating func toggleState() {
        switch state {
            case .selected:
                state = .banned
            case .notSelected:
                state = .selected
            case .banned:
                state = .notSelected
        }
    }
}

struct FilterPublicationDemographic: FilterTagProtocol {
    let tag: Manga.Attributes.PublicationDemographic
    var state: TagState = .notSelected
    var name: String {
        tag.rawValue
    }
    var id: String {
        tag.rawValue
    }
}

struct FilterContentRatings: FilterTagProtocol {
    var tag: Manga.Attributes.ContentRatings
    var name: String {
        tag.rawValue
    }
    var state: TagState = .notSelected
    var id: String {
        tag.rawValue
    }
}

struct FilterMangaStatus: FilterTagProtocol {
    var tag: Manga.Attributes.Status
    var name: String {
        tag.rawValue
    }
    var state: TagState = .notSelected
    var id: String {
        tag.rawValue
    }
}

enum QuerySortOption: String {
    case relevance
    // can be desc and asc
    case latestUploadedChapter, title, rating
    case createdAt, followedCount, year
    
    enum Order: String {
        case asc, desc
    }
}
