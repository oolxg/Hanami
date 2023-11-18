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

struct SearchFeature: ReducerProtocol {
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
        case searchHistoryRetrieved(Result<[SearchRequest], Never>)
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
                
                state.searchResultDidFetch = false
                state.isLoading = true
                
                return .run { send in
                    do {
                        let mangaListResponse = try await searchClient.makeSearchRequest(with: searchRequest.params)
                        
                        try await Task.sleep(seconds: 0.4)
                        await send(.searchResultFetched(.success(mangaListResponse), searchParams: nil))
                    } catch {
                        if let error = error as? AppError {
                            await send(.searchResultFetched(.failure(error), searchParams: nil))
                        }
                    }
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
                
                guard searchParams != state.lastSuccessfulSearchParams else {
                    return .none
                }
                
                state.searchResultDidFetch = false
                state.isLoading = true
                state.foundManga.removeAll()
                
                return .run { send in
                    do {
                        let mangaListResponse = try await searchClient.makeSearchRequest(with: searchParams)
                        
                        try await Task.sleep(seconds: 0.4)
                        await send(.searchResultFetched(.success(mangaListResponse), searchParams: searchParams))
                    } catch {
                        if let error = error as? AppError {
                            await send(.searchResultFetched(.failure(error), searchParams: nil))
                        }
                    }
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
                
                var effects = [
                    mangaClient.fetchStatistics(response.data.map(\.id))
                        .receive(on: mainQueue)
                        .catchToEffect(Action.mangaStatisticsFetched)
                ]
                
                if let searchParams {
                    effects.append(.task { .updateSearchHistory(searchParams) })
                }
                
                return .merge(effects)
                
            case .searchResultFetched(.failure(let error), _):
                logger.error("Failed to make search request: \(error)")
                hud.show(message: error.description)
                return hapticClient.generateNotificationFeedback(.error).fireAndForget()
                
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
