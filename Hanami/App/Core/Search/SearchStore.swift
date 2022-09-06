//
//  SearchFeature.swift
//  Hanami
//
//  Created by Oleg on 27/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct SearchState: Equatable {
    var mangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var filtersState = FiltersState()
    
    var areSearchResultsDownloaded = false
    
    var shouldShowEmptyResultsMessage: Bool {
        areSearchResultsDownloaded && !searchText.isEmpty && mangaThumbnailStates.isEmpty
    }
    
    @BindableState var searchSortOption: QuerySortOption = .relevance
    @BindableState var searchSortOptionOrder: QuerySortOption.Order = .desc
    @BindableState var resultsCount = 10

    @BindableState var searchText: String = ""
    
    // need this struct because of two things
    // 1) pass in search function one object, not bunch of arrays, string, enums, etc.
    // 2) to check, when going to make request, if the last request was with the same params,
    //      if yes - we don't need to make another request
    struct SearchParams: Equatable {
        let searchQuery: String
        let resultsCount: Int
        let tags: IdentifiedArrayOf<FilterTag>
        let publicationDemographic: IdentifiedArrayOf<FilterPublicationDemographic>
        let contentRatings: IdentifiedArrayOf<FilterContentRatings>
        let mangaStatuses: IdentifiedArrayOf<FilterMangaStatus>
        let sortOption: QuerySortOption
        let sortOptionOrder: QuerySortOption.Order
    }

    var lastSuccessfulRequestParams: SearchParams?
}

enum SearchAction: BindableAction {
    case searchForManga
    case resetSearchQuery
    case searchResultDownloaded(result: Result<Response<[Manga]>, AppError>, requestParams: SearchState.SearchParams)
    case mangaStatisticsFetched(result: Result<MangaStatisticsContainer, AppError>)

    case mangaThumbnailAction(UUID, MangaThumbnailAction)
    case filterAction(FiltersAction)

    case binding(BindingAction<SearchState>)
}

struct SearchEnvironment {
    let databaseClient: DatabaseClient
    let mangaClient: MangaClient
    let searchClient: SearchClient
    let cacheClient: CacheClient
    let imageClient: ImageClient
    let hudClient: HUDClient
    let hapticClient: HapticClient
}

let searchReducer: Reducer<SearchState, SearchAction, SearchEnvironment> = .combine(
    mangaThumbnailReducer
        .forEach(
            state: \.mangaThumbnailStates,
            action: /SearchAction.mangaThumbnailAction,
            environment: {
                .init(
                    databaseClient: $0.databaseClient,
                    hapticClient: $0.hapticClient,
                    imageClient: $0.imageClient,
                    cacheClient: $0.cacheClient,
                    mangaClient: $0.mangaClient,
                    hudClient: $0.hudClient
                )
            }
        ),
    filterReducer
        .pullback(
            state: \.filtersState,
            action: /SearchAction.filterAction,
            environment: {
                .init(searchClient: $0.searchClient)
            }
        ),
    Reducer { state, action, env in
        struct CancelSearch: Hashable { }
        switch action {
            case .resetSearchQuery:
                state.searchText = ""
                state.mangaThumbnailStates.removeAll()
                state.areSearchResultsDownloaded = false
                state.lastSuccessfulRequestParams = nil
                return .none
                
            case .searchForManga:
                let isAnySearchParamApplied = state.filtersState.isAnyFilterApplied || !state.searchText.isEmpty
                
                // if user clears the search string, we should delete all, what we've found for previous search request
                // and if user want to do the same request, e.g. only search string was used, no filters, it will be considered as
                // the same search request, and because of it we should also set 'nil' to lastRequestParams to avoid it
                guard isAnySearchParamApplied else {
                    state.areSearchResultsDownloaded = true
                    state.lastSuccessfulRequestParams = nil

                    let mangaIDs = state.mangaThumbnailStates.map(\.id)
                    // cancelling all subscriptions to clear cache for manga(because all instance are already destroyed)
                    return .cancel(
                        ids: mangaIDs.map { OnlineMangaViewState.CancelClearCache(mangaID: $0) }
                    )
                }
                
                let selectedTags = state.filtersState.allTags.filter { $0.state != .notSelected }
                let selectedPublicationDemographic = state.filtersState.publicationDemographics
                    .filter { $0.state != .notSelected }
                let selectedContentRatings = state.filtersState.contentRatings.filter { $0.state != .notSelected }
                let selectedMangaStatuses = state.filtersState.mangaStatuses.filter { $0.state != .notSelected }
                
                let searchParams = SearchState.SearchParams(
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
                state.mangaThumbnailStates.removeAll()

                return .concatenate(
                    .cancel(
                        ids: state.mangaThumbnailStates.map {
                            OnlineMangaViewState.CancelClearCache(mangaID: $0.id)
                        }
                    ),
                    
                    env.searchClient.makeSearchRequest(searchParams)
                        .delay(for: .seconds(0.4), scheduler: DispatchQueue.main)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect { SearchAction.searchResultDownloaded(result: $0, requestParams: searchParams) }
                        .cancellable(id: CancelSearch(), cancelInFlight: true)
                )
                
            case .searchResultDownloaded(let result, let requestParams):
                switch result {
                    case .success(let response):
                        state.lastSuccessfulRequestParams = requestParams
                        state.areSearchResultsDownloaded = true
                        state.mangaThumbnailStates = .init(
                            uniqueElements: response.data.map { MangaThumbnailState(manga: $0) }
                        )
                        
                        if !state.mangaThumbnailStates.isEmpty {
                            UIApplication.shared.endEditing()
                        }
                        
                        return env.searchClient.fetchStatistics(response.data.map(\.id))
                            .receive(on: DispatchQueue.main)
                            .catchToEffect(SearchAction.mangaStatisticsFetched)
                        
                    case .failure(let error):
                        print("error on downloading search results \(error)")
                        return env.hapticClient.generateNotificationFeedback(.error).fireAndForget()
                }
                
            case .mangaStatisticsFetched(let result):
                switch result {
                    case .success(let response):
                        for stat in response.statistics {
                            state.mangaThumbnailStates[id: stat.key]?.onlineMangaState!.statistics = stat.value
                        }
                        
                        return .none
                        
                    case .failure(let error):
                        print("error on downloading home page: \(error)")
                        return .none
                }
                
            case .binding(\.$searchText):
                struct DebounceForSearch: Hashable { }
                
                state.areSearchResultsDownloaded = false

                return .merge(
                    .cancel(id: CancelSearch()),
                    
                    Effect(value: .searchForManga)
                        .debounce(id: DebounceForSearch(), for: 0.8, scheduler: DispatchQueue.main)
                        .eraseToEffect()
                )
                
            case .binding:
                return Effect(value: .searchForManga)
                
            case .filterAction:
                return .none
                
            case .mangaThumbnailAction:
                return .none
        }
    }
    .binding()
)
