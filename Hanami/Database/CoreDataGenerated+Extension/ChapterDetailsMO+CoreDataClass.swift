//
//  ChapterDetailsMO+CoreDataClass.swift
//  Hanami
//
//  Created by Oleg on 10/07/2022.
//
//

import CoreData
import ModelKit
import DataTypeExtensions

@objc(ChapterDetailsMO) public class ChapterDetailsMO: NSManagedObject { }

extension ChapterDetailsMO: IdentifiableMO { }

extension ChapterDetailsMO {
    func toEntity() -> ChapterDetails {
        ChapterDetails(
            attributes: attributes.decodeToObject()!,
            id: id,
            relationships: relationships.decodeToObject()!
        )
    }
}

extension ChapterDetails {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext, withRelationships manga: MangaMO?) -> ChapterDetailsMO {
        let chapterDetailsMO = ChapterDetailsMO(context: context)
        
        chapterDetailsMO.id = id
        chapterDetailsMO.attributes = attributes.toData()!
        chapterDetailsMO.relationships = relationships.toData()!
        chapterDetailsMO.parentManga = manga!
        
        return chapterDetailsMO
    }
}

struct CoreDataChapterDetailsEntry: Equatable {
    let chapter: ChapterDetails
    let pagesCount: Int
}
