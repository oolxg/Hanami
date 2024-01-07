//
//  SearchFeature.swift
//  Hanami
//
//  Created by Oleg on 27/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIApplication
import ModelKit
import Utils
import Logger
import HUD
import HapticClient

@Reducer
struct SearchFeature {
    struct State: Equatable {
        var foundManga: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var filtersState = FiltersFeature.State()
        
        var searchResultDidFetch = false
        var isLoading = false
        
        @BindingState var searchSortOption = FiltersFeature.QuerySortOption.relevance
        @BindingState var searchSortOptionOrder = FiltersFeature.QuerySortOption.Order.desc
        @BindingState var resultsCount = 10
        
        @BindingState var searchText = ""
        
        var lastSuccessfulSearchParams: SearchParams?
        
        var searchHistory: IdentifiedArrayOf<SearchRequest> = []
    }
    
    enum Action: BindableAction {
        case updateSearchHistory(SearchParams?)
        case searchHistoryRetrieved([SearchRequest])
        case userTappedOnDeleteSearchHistoryButton
        
        case userTappedOnSearchHistory(SearchRequest)
        case searchForManga
        case cancelSearchButtonTapped
        case searchResultFetched(Result<Response<[Manga]>, AppError>, searchParams: SearchParams?)
        case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
        
        case mangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case filtersAction(FiltersFeature.Action)
        
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.searchClient) private var searchClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.hud) private var hud
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.logger) private var logger
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            struct CancelSearch: Hashable { }
            switch action {
            case .updateSearchHistory(let searchParams):
                if let searchParams {
                    let req = SearchRequest(params: searchParams)
                    if state.searchHistory.count == Defaults.Search.maxSearchHistorySize {
                        _ = state.searchHistory.removeLast()
                    }
                    
                    state.searchHistory.insert(req, at: 0)
                    
                    databaseClient.saveSearchRequest(req)
                    
                    return .none
                }
                
                return .run { send in
                    let history = await databaseClient.retrieveSearchRequestsHistory(
                        suffixLength: Defaults.Search.maxSearchHistorySize
                    )
                    
                    await send(.searchHistoryRetrieved(history))
                }
                
            case .searchHistoryRetrieved(let history):
                state.searchHistory = history.asIdentifiedArray
                state.searchHistory.sort { $0.date > $1.date }
                return .none
                
            case .userTappedOnDeleteSearchHistoryButton:
                state.searchHistory.removeAll()
                
                databaseClient.deleteOldSearchRequests(keepLast: 0)
                
                return .none
                
            case .userTappedOnSearchHistory(let searchRequest):
                state.filtersState.contentRatings = searchRequest.params.contentRatings
                state.filtersState.mangaStatuses = searchRequest.params.mangaStatuses
                state.filtersState.publicationDemographics = searchRequest.params.publicationDemographic
                state.filtersState.allTags = searchRequest.params.tags
                state.searchText = searchRequest.params.searchQuery
                
                state.searchResultDidFetch = false
                state.isLoading = true
                
                return .run { send in
                    let reult = await searchClient.makeSearchRequest(with: searchRequest.params)
                    
                    try await Task.sleep(seconds: 0.4)
                    await send(.searchResultFetched(reult, searchParams: nil))
                }
                .cancellable(id: CancelSearch(), cancelInFlight: true)
                
            case .cancelSearchButtonTapped:
                state.searchText = ""
                state.foundManga.removeAll()
                state.searchResultDidFetch = false
                state.lastSuccessfulSearchParams = nil
                state.isLoading = false
                
                return .cancel(id: CancelSearch())
                
            case .searchForManga:
                guard !state.searchText.isEmpty else {
                    return .run { await $0(.cancelSearchButtonTapped) }
                }
                
                let searchParams = SearchParams(
                    searchQuery: state.searchText,
                    resultsCount: state.resultsCount,
                    tags: state.filtersState.allTags,
                    publicationDemographic: state.filtersState.publicationDemographics,
                    contentRatings: state.filtersState.contentRatings,
                    mangaStatuses: state.filtersState.mangaStatuses,
                    sortOption: state.searchSortOption,
                    sortOptionOrder: state.searchSortOptionOrder
                )
                
                guard searchParams != state.lastSuccessfulSearchParams else {
                    return .none
                }
                
                state.searchResultDidFetch = false
                state.isLoading = true
                state.foundManga.removeAll()
                
                return .run { send in
                    let result = await searchClient.makeSearchRequest(with: searchParams)
                    
                    try await Task.sleep(seconds: 0.4)
                    await send(.searchResultFetched(result, searchParams: searchParams))
                }
                .cancellable(id: CancelSearch(), cancelInFlight: true)
                
            case .searchResultFetched(.success(let response), let searchParams):
                state.isLoading = false
                state.lastSuccessfulSearchParams = searchParams
                state.searchResultDidFetch = true
                state.foundManga = response.data
                    .map { MangaThumbnailFeature.State(manga: $0) }
                    .asIdentifiedArray
                
                if !state.foundManga.isEmpty {
                    UIApplication.shared.endEditing()
                }
                
                return .run { send in
                    let result = await mangaClient.fetchStatistics(for: response.data.map(\.id))
                    await send(.mangaStatisticsFetched(result))
                    
                    if let searchParams {
                        await send(.updateSearchHistory(searchParams))
                    }
                }
                
            case .searchResultFetched(.failure(let error), _):
                logger.error("Failed to make search request: \(error)")
                hud.show(message: error.description)
                hapticClient.generateNotificationFeedback(style: .error)
                return .none
                
            case .mangaStatisticsFetched(let result):
                switch result {
                case .success(let response):
                    for stat in response.statistics {
                        state.foundManga[id: stat.key]?.onlineMangaState!.statistics = stat.value
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to load statistics for found titles: \(error)")
                    return .none
                }
                
            case .binding(\.$searchText):
                struct DebounceForSearch: Hashable { }
                
                return .merge(
                    .cancel(id: CancelSearch()),
                    
                    .run { send in
                        try await withTaskCancellation(id: DebounceForSearch(), cancelInFlight: true) {
                            try await Task.sleep(seconds: 0.8)
                            await send(.searchForManga)
                        }
                    }
                )
                
            case .binding:
                return .run { await $0(.searchForManga) }
                
            case .filtersAction:
                return .none
                
            case .mangaThumbnailAction:
                return .none
            }
        }
        .forEach(\.foundManga, action: /Action.mangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        Scope(state: \.filtersState, action: /Action.filtersAction) {
            FiltersFeature()
        }
    }
}

public struct SearchParams: Equatable {
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
