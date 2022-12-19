//
//  SearchParams.swift
//  Hanami
//
//  Created by Oleg on 19.12.22.
//

import Foundation
import typealias IdentifiedCollections.IdentifiedArrayOf
import CoreData

struct SearchParams: Equatable {
    let searchQuery: String
    let resultsCount: Int
    let tags: IdentifiedArrayOf<FilterFeature.FiltersTag>
    let publicationDemographic: IdentifiedArrayOf<FilterFeature.PublicationDemographic>
    let contentRatings: IdentifiedArrayOf<FilterFeature.ContentRatings>
    let mangaStatuses: IdentifiedArrayOf<FilterFeature.MangaStatus>
    let sortOption: FilterFeature.QuerySortOption
    let sortOptionOrder: FilterFeature.QuerySortOption.Order
}

extension SearchParams: Codable { }
