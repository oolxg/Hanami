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
    var searchManga: (String, // user's search query
                      IdentifiedArrayOf<FilterTag>,
                      IdentifiedArrayOf<FilterPublicationDemographic>,
                      IdentifiedArrayOf<FilterContentRatings>,
                      IdentifiedArrayOf<FilterMangaStatus>,
                      QuerySortOption,
                      QuerySortOption.Order,
                      JSONDecoder) -> Effect<Response<[Manga]>, APIError>
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
                
                return env.searchManga(
                    state.searchText,
                    state.filtersState.allTags,
                    state.filtersState.publicationDemographics,
                    state.filtersState.contentRatings,
                    state.filtersState.mangaStatuses,
                    state.searchSortOption,
                    state.searchSortOptionOrder,
                    env.decoder()
                )
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
                return .none
                
            case .filterAction(_):
                return .none
                
            case .mangaThumbnailAction(_, _):
                return .none
        }
    }
)
.binding()
