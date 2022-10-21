//
//  MangaMO+CoreDataProperties.swift
//  Hanami
//
//  Created by Oleg on 10/07/2022.
//
//

import CoreData


extension MangaMO {
    @NSManaged public var attributes: Data
    @NSManaged public var id: UUID
    @NSManaged public var relationships: Data
    @NSManaged public var chapterDetailsSet: Set<ChapterDetailsMO>
}

extension MangaMO: Identifiable { }
