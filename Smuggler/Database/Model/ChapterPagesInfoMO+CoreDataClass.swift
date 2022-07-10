//
//  ChapterPagesInfoMO+CoreDataClass.swift
//  Smuggler
//
//  Created by mk.pwnz on 10/07/2022.
//
//

import Foundation
import CoreData

@objc(ChapterPagesInfoMO)
public class ChapterPagesInfoMO: NSManagedObject { }


extension ChapterPagesInfoMO: ManagedObjectProtocol {
    func toEntity() -> ChapterPagesInfo {
        ChapterPagesInfo(
            baseURL: baseURL,
            chapter: chapter.decodeToObject()!
        )
    }
}

extension ChapterPagesInfoMO: ManagedObjectConvertible {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext, withRelationships chapterDetailsMO: ChapterDetailsMO?) -> ChapterPagesInfoMO {
        let chapterPagesInfoMO = ChapterPagesInfoMO(context: context)
        
        chapterPagesInfoMO.baseURL = baseURL
        chapterPagesInfoMO.chapter = chapter.toData()!
        chapterPagesInfoMO.fromChapter = chapterDetailsMO!
        
        return chapterPagesInfoMO
    }
}
