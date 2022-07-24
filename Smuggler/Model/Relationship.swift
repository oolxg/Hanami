//
//  Relationship.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation

// MARK: - Relationship
struct Relationship: Codable {
    let id: UUID
    let type: ResponseDataType
    let related: RelatedType?

    enum RelatedType: String, Codable {
        case monochrome
        case mainStory = "main_story"
        case adaptedFrom = "adapted_from"
        case basedOn = "based_on"
        case prequel
        case sideStory = "side_story"
        case doujinshi
        case sameFranchise = "same_franchise"
        case sharedUniverse = "shared_universe"
        case sequel
        case spinOff = "spin_off"
        case alternateStory = "alternate_story"
        case alternateVersion = "alternate_version"
        case preserialization, colored, serialization
    }
}
