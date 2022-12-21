//
//  SearchFeature.swift
//  Hanami
//
//  Created by Oleg on 27/05/2022.
//

import Foundation
import ComposableArchitecture
import class SwiftUI.UIApplication

struct SearchFeature: ReducerProtocol {
    struct State: Equatable {
        var foundManga: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        var filtersState = FiltersFeature.State()
        
        var searchResultsFetched = false
        var isLoading = false
        
        @BindableState var searchSortOption = FiltersFeature.QuerySortOption.relevance
        @BindableState var searchSortOptionOrder = FiltersFeature.QuerySortOption.Order.desc
        @BindableState var resultsCount = 10
        
        @BindableState var searchText = ""
        
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
        case searchResultDownloaded(result: Result<Response<[Manga]>, AppError>, requestParams: SearchParams?)
        case mangaStatisticsFetched(result: Result<MangaStatisticsContainer, AppError>)
        
        case mangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case filtersAction(FiltersFeature.Action)
        
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.searchClient) private var searchClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.hudClient) private var hudClient
    @Dependency(\.logger) private var logger
    
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
                    .receive(on: DispatchQueue.main)
                    .catchToEffect(Action.searchHistoryRetrieved)
                
            case .searchHistoryRetrieved(let result):
                switch result {
                case .success(let searchHistory):
                    state.searchHistory = .init(uniqueElements: searchHistory)
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
                    .delay(for: .seconds(0.4), scheduler: DispatchQueue.main)
                    .receive(on: DispatchQueue.main)
                    .catchToEffect { .searchResultDownloaded(result: $0, requestParams: nil) }
                    .cancellable(id: CancelSearch(), cancelInFlight: true)
                
            case .cancelSearchButtonTapped:
                // cancelling all subscriptions to clear cache for manga(because all instance will be destroyed)
                let mangaIDs = state.foundManga.map(\.id)
                
                state.searchText = ""
                state.foundManga.removeAll()
                state.searchResultsFetched = false
                state.lastSuccessfulRequestParams = nil
                state.isLoading = false
                
                return .merge(
                    .cancel(id: CancelSearch()),
                    
                    .cancel(ids: mangaIDs.map { OnlineMangaFeature.CancelClearCache(mangaID: $0) })
                )
                
            case .searchForManga:
                guard !state.searchText.isEmpty else {
                    return .task { .cancelSearchButtonTapped }
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
                
                state.searchResultsFetched = false
                state.isLoading = true
                state.foundManga.removeAll()
                
                return .concatenate(
                    .cancel(
                        ids: state.foundManga.map {
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
                    state.searchResultsFetched = true
                    state.foundManga = .init(
                        uniqueElements: response.data.map { MangaThumbnailFeature.State(manga: $0) }
                    )
                    
                    if !state.foundManga.isEmpty {
                        UIApplication.shared.endEditing()
                    }
                    
                    var effects = [
                        searchClient.fetchStatistics(response.data.map(\.id))
                            .receive(on: DispatchQueue.main)
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
        .forEach(\.foundManga, action: /Action.mangaThumbnailAction) {
            MangaThumbnailFeature()
        }
        Scope(state: \.filtersState, action: /Action.filtersAction) {
            FiltersFeature()
        }
    }
}
