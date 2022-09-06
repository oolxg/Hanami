//
//  MangaMO+CoreDataProperties.swift
//  Hanami
//
//  Created by Oleg on 10/07/2022.
//
//

import Foundation
import CoreData


extension MangaMO {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MangaMO> {
        NSFetchRequest<MangaMO>(entityName: "MangaMO")
    }

    @NSManaged public var attributes: Data
    @NSManaged public var id: UUID
    @NSManaged public var relationships: Data
    @NSManaged public var chapterDetailsSet: Set<ChapterDetailsMO>
}

// MARK: Generated accessors for chapterDetailsSet
extension MangaMO {
    @objc(addChapterDetailsSetObject:)
    @NSManaged public func addToChapterDetailsSet(_ value: ChapterDetailsMO)

    @objc(removeChapterDetailsSetObject:)
    @NSManaged public func removeFromChapterDetailsSet(_ value: ChapterDetailsMO)

    @objc(addChapterDetailsSet:)
    @NSManaged public func addToChapterDetailsSet(_ values: Set<ChapterDetailsMO>)

    @objc(removeChapterDetailsSet:)
    @NSManaged public func removeFromChapterDetailsSet(_ values: Set<ChapterDetailsMO>)
}

extension MangaMO: Identifiable { }
