//
//  MangaMO+CoreDataProperties.swift
//  Smuggler
//
//  Created by mk.pwnz on 03/07/2022.
//
//

import Foundation
import CoreData

extension MangaMO {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MangaMO> {
        NSFetchRequest<MangaMO>(entityName: "MangaMO")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var attributes: Data
    @NSManaged public var relationships: Data
    @NSManaged public var chapters: NSSet?
}

    // MARK: Generated accessors for manga
extension MangaMO {
    @objc(addMangaObject:)
    @NSManaged public func addToManga(_ value: ChapterDetailsMO)
    
    @objc(removeMangaObject:)
    @NSManaged public func removeFromManga(_ value: ChapterDetailsMO)
    
    @objc(addManga:)
    @NSManaged public func addToManga(_ values: NSSet)
    
    @objc(removeManga:)
    @NSManaged public func removeFromManga(_ values: NSSet)
}

extension MangaMO: Identifiable { }
