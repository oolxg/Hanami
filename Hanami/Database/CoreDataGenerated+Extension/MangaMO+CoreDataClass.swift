//
//  MangaMO+CoreDataClass.swift
//  Hanami
//
//  Created by Oleg on 10/07/2022.
//
//

import CoreData

@objc(MangaMO)
public class MangaMO: NSManagedObject { }

extension MangaMO: IdentifiableMO { }

extension MangaMO {
    func toEntity() -> Manga {
        Manga(
            id: id,
            attributes: attributes.decodeToObject()!,
            relationships: relationships.decodeToObject()!
        )
    }
    
    var savedForOfflineReading: Bool {
        !chapterDetailsSet.isEmpty
    }
}

extension Manga {
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
    var chapterDetailsList: [CoreDataChapterDetailsEntry] {
        chapterDetailsSet.map { .init(chapter: $0.toEntity(), pagesCount: $0.pagesCount) }.sorted {
            ($0.chapter.attributes.index ?? -1) > ($1.chapter.attributes.index ?? -1)
        }
    }
}
