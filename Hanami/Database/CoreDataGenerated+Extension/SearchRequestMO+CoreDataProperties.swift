//
//  SearchRequestMO+CoreDataProperties.swift
//  Hanami
//
//  Created by Oleg on 19.12.22.
//
//

import Foundation
import CoreData


extension SearchRequestMO {
    @NSManaged public var date: Date
    @NSManaged public var id: UUID
    @NSManaged public var params: Data
}

extension SearchRequestMO: Identifiable { }
