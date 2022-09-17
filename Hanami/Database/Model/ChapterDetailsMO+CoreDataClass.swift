//
//  ChapterDetailsMO+CoreDataClass.swift
//  Hanami
//
//  Created by Oleg on 10/07/2022.
//
//

import Foundation
import CoreData

@objc(ChapterDetailsMO)
public class ChapterDetailsMO: NSManagedObject { }

extension ChapterDetailsMO: IdentifiableMO { }

extension ChapterDetailsMO: ManagedObjectProtocol {
    func toEntity() -> ChapterDetails {
        ChapterDetails(
            attributes: attributes.decodeToObject()!,
            id: id,
            relationships: relationships.decodeToObject()!
        )
    }
}

extension ChapterDetails: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext, withRelationships manga: MangaMO?) -> ChapterDetailsMO {
        let chapterDetailsMO = ChapterDetailsMO(context: context)
        
        chapterDetailsMO.id = id
        chapterDetailsMO.attributes = attributes.toData()!
        chapterDetailsMO.relationships = relationships.toData()!
        chapterDetailsMO.fromManga = manga!
        
        return chapterDetailsMO
    }
}

struct CachedChapterEntry: Equatable {
    let chapter: ChapterDetails
    let pagesCount: Int
}
