//
//  SearchFeature.swift
//  Hanami
//
//  Created by Oleg on 27/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct SearchFeature: ReducerProtocol {
    struct State: Equatable {
        var searchResults: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var filtersState = FilterFeature.State()
        
        var areSearchResultsDownloaded = false
        var isLoading = false
        
        var shouldShowEmptyResultsMessage: Bool {
            areSearchResultsDownloaded && !searchText.isEmpty && searchResults.isEmpty
        }
        
        @BindableState var searchSortOption: FilterFeature.QuerySortOption = .relevance
        @BindableState var searchSortOptionOrder: FilterFeature.QuerySortOption.Order = .desc
        @BindableState var resultsCount = 10
        
        @BindableState var searchText: String = ""
        
        var lastSuccessfulRequestParams: SearchParams?
    }
    
    // need this struct because of two things
    // 1) pass in search function one object, not bunch of arrays, string, enums, etc.
    // 2) to check, when going to make request, if the last request was with the same params,
    //      if yes - we don't need to make another request
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
    
    enum Action: BindableAction {
        case searchForManga
        case resetSearch
        case searchResultDownloaded(result: Result<Response<[Manga]>, AppError>, requestParams: SearchParams)
        case mangaStatisticsFetched(result: Result<MangaStatisticsContainer, AppError>)
        
        case mangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case filtersAction(FilterFeature.Action)
        
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.searchClient) private var searchClient
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.logger) private var logger
    
    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce { state, action in
            struct CancelSearch: Hashable { }
            switch action {
                case .resetSearch:
                        // cancelling all subscriptions to clear cache for manga(because all instance will be destroyed)
                    let mangaIDs = state.searchResults.map(\.id)
                    
                    state.searchText = ""
                    state.searchResults.removeAll()
                    state.areSearchResultsDownloaded = false
                    state.lastSuccessfulRequestParams = nil
                    state.isLoading = false
                    
                    return .merge(
                        .cancel(id: CancelSearch()),
                        .cancel(ids: mangaIDs.map { OnlineMangaFeature.CancelClearCache(mangaID: $0) })
                    )
                    
                case .searchForManga:
                    let isAnySearchParamApplied = state.filtersState.isAnyFilterApplied || !state.searchText.isEmpty
                        // if user clears the search string, we should delete all, what we've found for previous search request
                        // and if user want to do the same request, e.g. only search string was used, no filters, it will be considered as
                        // the same search request, and because of it we should also set 'nil' to lastRequestParams to avoid it
                    guard isAnySearchParamApplied else {
                        return .task { .resetSearch }
                    }
                    
                    let selectedTags = state.filtersState.allTags.filter { $0.state != .notSelected }
                    let selectedPublicationDemographic = state.filtersState.publicationDemographics
                        .filter { $0.state != .notSelected }
                    let selectedContentRatings = state.filtersState.contentRatings.filter { $0.state != .notSelected }
                    let selectedMangaStatuses = state.filtersState.mangaStatuses.filter { $0.state != .notSelected }
                    
                    let searchParams = SearchParams(
                        searchQuery: state.searchText,
                        resultsCount: state.resultsCount,
                        tags: selectedTags,
                        publicationDemographic: selectedPublicationDemographic,
                        contentRatings: selectedContentRatings,
                        mangaStatuses: selectedMangaStatuses,
                        sortOption: state.searchSortOption,
                        sortOptionOrder: state.searchSortOptionOrder
                    )
                    
                    guard searchParams != state.lastSuccessfulRequestParams else {
                        return .none
                    }
                    
                    state.areSearchResultsDownloaded = false
                    state.isLoading = true
                    state.searchResults.removeAll()
                    
                    return .concatenate(
                        .cancel(
                            ids: state.searchResults.map {
                                OnlineMangaFeature.CancelClearCache(mangaID: $0.id)
                            }
                        ),
                        
                        searchClient.makeSearchRequest(searchParams)
                            .delay(for: .seconds(0.4), scheduler: DispatchQueue.main)
                            .receive(on: DispatchQueue.main)
                            .catchToEffect { .searchResultDownloaded(result: $0, requestParams: searchParams) }
                            .cancellable(id: CancelSearch(), cancelInFlight: true)
                    )
                    
                case .searchResultDownloaded(let result, let requestParams):
                    state.isLoading = false
                    
                    switch result {
                        case .success(let response):
                            state.lastSuccessfulRequestParams = requestParams
                            state.areSearchResultsDownloaded = true
                            state.searchResults = .init(
                                uniqueElements: response.data.map { MangaThumbnailFeature.State(manga: $0) }
                            )
                            
                            if !state.searchResults.isEmpty {
                                UIApplication.shared.endEditing()
                            }
                            
                            return searchClient.fetchStatistics(response.data.map(\.id))
                                .receive(on: DispatchQueue.main)
                                .catchToEffect(Action.mangaStatisticsFetched)
                            
                        case .failure(let error):
                            logger.error("Failed to make search request: \(error)")
                            hudClient.show(message: error.description)
                            return hapticClient.generateNotificationFeedback(.error).fireAndForget()
                    }
                    
                case .mangaStatisticsFetched(let result):
                    switch result {
                        case .success(let response):
                            for stat in response.statistics {
                                state.searchResults[id: stat.key]?.onlineMangaState!.statistics = stat.value
                            }
                            
                            return .none
                            
                        case .failure(let error):
                            logger.error("Failed to load statistics for found titles: \(error)")
                            return .none
                    }
                    
                case .binding(\.$searchText):
                    struct DebounceForSearch: Hashable { }
                    
                    state.areSearchResultsDownloaded = false
                    
                    return .merge(
                        .cancel(id: CancelSearch()),
                        
                            .task { .searchForManga }
                            .debounce(id: DebounceForSearch(), for: 0.8, scheduler: DispatchQueue.main)
                            .eraseToEffect()
                    )
                    
                case .binding:
                    return .task { .searchForManga }
                    
                case .filtersAction:
                    return .none
                    
                case .mangaThumbnailAction:
                    return .none
            }
        }
        .forEach(\.searchResults, action: /Action.mangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        Scope(state: \.filtersState, action: /Action.filtersAction) {
            FilterFeature()
        }
    }
}
