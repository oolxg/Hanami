//
//  RelationshipType.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import Foundation

// MARK: - ResponseDataType
enum ResponseDataType: String {
    case manga, chapter
    case coverArt = "cover_art"
    case author, artist
    case scanlationGroup = "scanlation_group"
    case tag, user, leader, member
    case customList = "custom_list"
}

extension ResponseDataType: Codable { }
