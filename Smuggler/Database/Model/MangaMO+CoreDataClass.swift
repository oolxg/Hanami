//
//  MangaMO+CoreDataClass.swift
//  Smuggler
//
//  Created by mk.pwnz on 10/07/2022.
//
//

import Foundation
import CoreData

@objc(MangaMO)
public class MangaMO: NSManagedObject { }

extension MangaMO: IdentifiableMO { }

extension MangaMO: ManagedObjectProtocol {
    func toEntity() -> Manga {
        Manga(
            id: id,
            attributes: attributes.decodeToObject()!,
            relationships: relationships.decodeToObject()!
        )
    }
}

extension Manga: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext, withRelationships chapters: Set<ChapterDetailsMO>? = []) -> MangaMO {
        let mangaMO = MangaMO(context: context)
        
        mangaMO.id = id
        mangaMO.attributes = attributes.toData()!
        mangaMO.relationships = relationships.toData()!
        mangaMO.chapterDetailsSet = chapters!
        
        return mangaMO
    }
}

extension MangaMO {
    var chapterDetailsList: [(chapter: ChapterDetails, pagesCount: Int)] {
        chapterDetailsSet.map { (chapter: $0.toEntity(), pagesCount: $0.pagesCount) }.sorted {
            ($0.chapter.attributes.chapterIndex ?? -1) > ($1.chapter.attributes.chapterIndex ?? -1)
        }
    }
}
