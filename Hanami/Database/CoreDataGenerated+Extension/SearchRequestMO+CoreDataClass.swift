//
//  SearchRequestMO+CoreDataClass.swift
//  Hanami
//
//  Created by Oleg on 19.12.22.
//
//

import Foundation
import CoreData


public class SearchRequestMO: NSManagedObject { }

extension SearchRequestMO: IdentifiableMO { }

extension SearchRequestMO {
    func toEntity() -> SearchRequest {
        SearchRequest(
            id: id,
            params: params.decodeToObject()!,
            date: date
        )
    }
}

extension SearchRequest {
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext, withRelationships relationships: Any? = nil) -> SearchRequestMO {
        let searchRequestMO = SearchRequestMO(context: context)
        
        searchRequestMO.id = id
        searchRequestMO.params = params.toData()!
        searchRequestMO.date = date
        
        return searchRequestMO
    }
}
