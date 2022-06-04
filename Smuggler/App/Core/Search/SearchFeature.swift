//
//  SearchFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 27/05/2022.
//

import Foundation
import ComposableArchitecture

struct SearchState: Equatable {
    var mangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
    var filtersState = FiltersState()
    
    var isFilterPopoverPresented: Bool = false
    
    var isSearchResultsDownloaded: Bool = false
    
    var shouldShowEmptyResultsMessage: Bool {
        isSearchResultsDownloaded && !searchText.isEmpty && mangaThumbnailStates.isEmpty
    }
    
    @BindableState var searchSortOption: QuerySortOption = .relevance
    @BindableState var searchSortOptionOrder: QuerySortOption.Order = .desc
    
    var searchText: String = ""
    
    // need this struct because of two things
    // 1) pass in search function one object, not bunch of arrays, string, enums, etc.
    // 2) to check, when going to make request, if the last request was with the same params,
    //      if yes - we don't need to make another request
    struct RequestParams: Equatable {
        let searchQuery: String
        let tags: IdentifiedArrayOf<FilterTag>
        let publicationDemographic: IdentifiedArrayOf<FilterPublicationDemographic>
        let contentRatings: IdentifiedArrayOf<FilterContentRatings>
        let mangaStatuses: IdentifiedArrayOf<FilterMangaStatus>
        let sortOption: QuerySortOption
        let sortOptionOrder : QuerySortOption.Order
    }

    var lastRequestParams: RequestParams? = nil
}

enum SearchAction: BindableAction {
    case searchForManga
    case searchResultDownloaded(Result<Response<[Manga]>, APIError>)
    case searchStringChanged(String)
    
    case mangaThumbnailAction(UUID, MangaThumbnailAction)
    case filterAction(FiltersAction)
    
    case binding(BindingAction<SearchState>)
    
}

struct SearchEnvironment {
    var searchManga: (SearchState.RequestParams, JSONDecoder) -> Effect<Response<[Manga]>, APIError>
}

let searchReducer: Reducer<SearchState, SearchAction, SystemEnvironment<SearchEnvironment>> = .combine(
    mangaThumbnailReducer
        .forEach(
            state: \.mangaThumbnailStates,
            action: /SearchAction.mangaThumbnailAction,
            environment: { _ in .live(
                environment: .init(
                    loadThumbnailInfo: downloadThumbnailInfo
                ),
                isMainQueueWithAnimation: true
            ) }
        ),
    filterReducer
        .pullback(
            state: \.filtersState,
            action: /SearchAction.filterAction,
            environment: { _ in
                .live(
                    environment: .init(getListOfTags: downloadTagsList),
                    isMainQueueWithAnimation: true
                )
            }
        ),
    Reducer { state, action, env in
        switch action {
            case .searchStringChanged(let query):
                struct DebounceForSearch: Hashable { }
                
                state.isSearchResultsDownloaded = false
                state.searchText = query
                return Effect(value: SearchAction.searchForManga)
                    .debounce(id: DebounceForSearch(), for: 0.8, scheduler: env.mainQueue())
                    .eraseToEffect()
                
            case .searchForManga:
                guard !state.searchText.isEmpty else {
                    state.isSearchResultsDownloaded = true
                    state.mangaThumbnailStates.removeAll()
                    return .none
                }
                
                let requestParams = SearchState.RequestParams(
                    searchQuery: state.searchText,
                    tags: state.filtersState.allTags.filter { $0.state != .notSelected },
                    publicationDemographic: state.filtersState.publicationDemographics.filter { $0.state != .notSelected },
                    contentRatings: state.filtersState.contentRatings.filter { $0.state != .notSelected },
                    mangaStatuses: state.filtersState.mangaStatuses.filter { $0.state != .notSelected },
                    sortOption: state.searchSortOption,
                    sortOptionOrder: state.searchSortOptionOrder
                )
                
                guard requestParams != state.lastRequestParams else {
                    return .none
                }
                
                state.lastRequestParams = requestParams
                
                return env.searchManga(requestParams, env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(SearchAction.searchResultDownloaded)
                
            case .searchResultDownloaded(let result):
                switch result {
                    case .success(let response):
                        state.isSearchResultsDownloaded = true
                        state.mangaThumbnailStates = .init(uniqueElements: response.data.map { MangaThumbnailState(manga: $0) })
                        return .none
                    case .failure(let error):
                        print("error on downloading search results \(error)")
                        return .none
                }
                
            case .binding:
                return Effect(value: SearchAction.searchForManga)
                
            case .filterAction(_):
                return .none
                
            case .mangaThumbnailAction(_, _):
                return .none
        }
    }
)
.binding()
