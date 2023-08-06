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

struct SearchFeature: ReducerProtocol {
    struct State: Equatable {
        var foundManga: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var filtersState = FiltersFeature.State()
        
        var searchResultsFetched = false
        var isLoading = false
        
        @BindingState var searchSortOption = FiltersFeature.QuerySortOption.relevance
        @BindingState var searchSortOptionOrder = FiltersFeature.QuerySortOption.Order.desc
        @BindingState var resultsCount = 10
        
        @BindingState var searchText = ""
        
        var lastSuccessfulRequestParams: SearchParams?
        
        var searchHistory: IdentifiedArrayOf<SearchRequest> = []
    }
    
    enum Action: BindableAction {
        case updateSearchHistory(SearchParams?)
        case searchHistoryRetrieved(Result<[SearchRequest], Never>)
        case userTappedOnDeleteSearchHistoryButton
        
        case userTappedOnSearchHistory(SearchRequest)
        case searchForManga
        case cancelSearchButtonTapped
        case searchResultDownloaded(Result<Response<[Manga]>, AppError>, requestParams: SearchParams?)
        case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
        
        case mangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case filtersAction(FiltersFeature.Action)
        
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.searchClient) private var searchClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue
    
    var body: some ReducerProtocol<State, Action> {
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
                    
                    return databaseClient.saveSearchRequest(req)
                        .fireAndForget()
                }
                
                return databaseClient.retrieveSearchRequests(suffixLength: Defaults.Search.maxSearchHistorySize)
                    .receive(on: mainQueue)
                    .catchToEffect(Action.searchHistoryRetrieved)
                
            case .searchHistoryRetrieved(let result):
                switch result {
                case .success(let searchHistory):
                    state.searchHistory = searchHistory.asIdentifiedArray
                    state.searchHistory.sort { $0.date > $1.date }
                    return .none
                    
                case .failure:
                    return .none
                }
                
            case .userTappedOnDeleteSearchHistoryButton:
                state.searchHistory.removeAll()
                
                return databaseClient
                    .deleteOldSearchRequests(keepLast: 0)
                    .fireAndForget()
                
            case .userTappedOnSearchHistory(let searchRequest):
                state.filtersState.contentRatings = searchRequest.params.contentRatings
                state.filtersState.mangaStatuses = searchRequest.params.mangaStatuses
                state.filtersState.publicationDemographics = searchRequest.params.publicationDemographic
                state.filtersState.allTags = searchRequest.params.tags
                state.searchText = searchRequest.params.searchQuery
                
                state.searchResultsFetched = false
                state.isLoading = true
                
                return searchClient.makeSearchRequest(searchRequest.params)
                    .delay(for: .seconds(0.4), scheduler: mainQueue)
                    .receive(on: mainQueue)
                    .catchToEffect { .searchResultDownloaded($0, requestParams: nil) }
                    .cancellable(id: CancelSearch(), cancelInFlight: true)
                
            case .cancelSearchButtonTapped:
                state.searchText = ""
                state.foundManga.removeAll()
                state.searchResultsFetched = false
                state.lastSuccessfulRequestParams = nil
                state.isLoading = false
                
                return .cancel(id: CancelSearch())
                
            case .searchForManga:
                guard !state.searchText.isEmpty else {
                    return .task { .cancelSearchButtonTapped }
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
                
                guard searchParams != state.lastSuccessfulRequestParams else {
                    return .none
                }
                
                state.searchResultsFetched = false
                state.isLoading = true
                state.foundManga.removeAll()
                
                return searchClient.makeSearchRequest(searchParams)
                    .delay(for: .seconds(0.4), scheduler: mainQueue)
                    .receive(on: mainQueue)
                    .catchToEffect { .searchResultDownloaded($0, requestParams: searchParams) }
                    .cancellable(id: CancelSearch(), cancelInFlight: true)
                
                
            case .searchResultDownloaded(let result, let requestParams):
                state.isLoading = false
                
                switch result {
                case .success(let response):
                    state.lastSuccessfulRequestParams = requestParams
                    state.searchResultsFetched = true
                    state.foundManga = response.data
                        .map { MangaThumbnailFeature.State(manga: $0) }
                        .asIdentifiedArray
                    
                    if !state.foundManga.isEmpty {
                        UIApplication.shared.endEditing()
                    }
                    
                    var effects = [
                        mangaClient.fetchStatistics(response.data.map(\.id))
                            .receive(on: mainQueue)
                            .catchToEffect(Action.mangaStatisticsFetched)
                    ]
                    
                    if let requestParams {
                        effects.append(.task { .updateSearchHistory(requestParams) })
                    }
                    
                    return .merge(effects)
                    
                case .failure(let error):
                    logger.error("Failed to make search request: \(error)")
                    hudClient.show(message: error.description)
                    return hapticClient.generateNotificationFeedback(.error).fireAndForget()
                }
                
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
                    
                    .task { .searchForManga }
                        .debounce(id: DebounceForSearch(), for: 0.8, scheduler: mainQueue)
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
        .forEach(\.foundManga, action: /Action.mangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        Scope(state: \.filtersState, action: /Action.filtersAction) {
            FiltersFeature()
        }
    }
}

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
