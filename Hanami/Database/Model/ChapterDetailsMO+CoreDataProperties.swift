//
//  ChapterDetailsMO+CoreDataProperties.swift
//  Hanami
//
//  Created by Oleg on 10/07/2022.
//
//

import Foundation
import CoreData


extension ChapterDetailsMO {
    @NSManaged public var attributes: Data
    @NSManaged public var id: UUID
    @NSManaged public var pagesCount: Int
    @NSManaged public var relationships: Data
    @NSManaged public var fromManga: MangaMO
}

extension ChapterDetailsMO: Identifiable { }
