//
//  SearchParams.swift
//  Hanami
//
//  Created by Oleg on 19.12.22.
//

import Foundation
import typealias IdentifiedCollections.IdentifiedArrayOf

struct SearchParams: Equatable {
    let searchQuery: String
    let resultsCount: Int
    let tags: IdentifiedArrayOf<FiltersFeature.FiltersTag>
    let publicationDemographic: IdentifiedArrayOf<FiltersFeature.PublicationDemographic>
    let contentRatings: IdentifiedArrayOf<FiltersFeature.ContentRatings>
    let mangaStatuses: IdentifiedArrayOf<FiltersFeature.MangaStatus>
    let sortOption: FiltersFeature.QuerySortOption
    let sortOptionOrder: FiltersFeature.QuerySortOption.Order
}

extension SearchParams: Codable { }
