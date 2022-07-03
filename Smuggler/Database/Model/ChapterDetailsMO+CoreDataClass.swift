//
//  ChapterDetailsMO+CoreDataClass.swift
//  Smuggler
//
//  Created by mk.pwnz on 03/07/2022.
//
//

import Foundation
import CoreData

@objc(ChapterDetailsMO)
public class ChapterDetailsMO: NSManagedObject { }

extension ChapterDetailsMO: IdentifiableMO { }

extension ChapterDetailsMO: ManagedObjectProtocol {
    func toEntity(decoder: JSONDecoder = AppUtil.decoder) -> ChapterDetails {
        ChapterDetails(
            attributes: attributes.decodeToObject()!,
            id: id,
            relationships: relationships.decodeToObject()!,
            type: .chapter
        )
    }
}

extension ChapterDetailsMO {
    func getManga() -> Manga? {
        fromManga?.toEntity()
    }
}
