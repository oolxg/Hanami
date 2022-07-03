//
//  MangaMO+CoreDataClass.swift
//  Smuggler
//
//  Created by mk.pwnz on 03/07/2022.
//
//

import Foundation
import CoreData

@objc(MangaMO)
public class MangaMO: NSManagedObject { }

extension MangaMO: IdentifiableMO { }

extension MangaMO: ManagedObjectProtocol {
    func toEntity(decoder: JSONDecoder = AppUtil.decoder) -> Manga {
        return Manga(
            id: id,
            type: .manga,
            attributes: attributes.decodeToObject()!,
            relationships: relationships.decodeToObject()!
        )
    }
}

extension Manga: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext) -> MangaMO {
        let mangaMO = MangaMO(context: context)
        
        mangaMO.id = id
        mangaMO.attributes = attributes.toData()!
        mangaMO.relationships = relationships.toData()!
        print(String(data: mangaMO.attributes, encoding: .utf8)!)
        return mangaMO
    }
}

extension MangaMO {
    func getChapters() -> [ChapterDetails] {
        let set = chapters as? Set<ChapterDetails> ?? []
        
        return set.sorted { lhs, rhs in
            (lhs.attributes.chapterIndex ?? 99999) > (rhs.attributes.chapterIndex ?? 99999)
        }
    }
}
