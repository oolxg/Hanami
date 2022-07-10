//
//  ChapterPagesInfoMO+CoreDataProperties.swift
//  Smuggler
//
//  Created by mk.pwnz on 10/07/2022.
//
//

import Foundation
import CoreData


extension ChapterPagesInfoMO {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChapterPagesInfoMO> {
        NSFetchRequest<ChapterPagesInfoMO>(entityName: "ChapterPagesInfoMO")
    }

    @NSManaged public var baseURL: String
    @NSManaged public var chapter: Data
    @NSManaged public var chapterID: UUID
    @NSManaged public var fromChapter: ChapterDetailsMO
}

extension ChapterPagesInfoMO: Identifiable { }
