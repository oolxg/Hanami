//
//  ChapterDetailsMO+CoreDataProperties.swift
//  Smuggler
//
//  Created by mk.pwnz on 03/07/2022.
//
//

import Foundation
import CoreData


extension ChapterDetailsMO {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChapterDetailsMO> {
        NSFetchRequest<ChapterDetailsMO>(entityName: "ChapterDetailsMO")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var attributes: Data
    @NSManaged public var relationships: Data
    @NSManaged public var fromManga: MangaMO?
}

extension ChapterDetailsMO: Identifiable { }
