//
//  RelationshipType.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation

// MARK: - ResponseDataType
enum ResponseDataType: String, Codable {
    case manga, chapter
    case coverArt = "cover_art"
    case author, artist
    case scanlationGroup = "scanlation_group"
    case tag, user
    case customList = "custom_list"
}
