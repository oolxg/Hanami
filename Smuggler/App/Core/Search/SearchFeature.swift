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
    
    var isFilterPopoverPresented = false
    
    var isSearchResultsDownloaded = false
    
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
        let sortOptionOrder: QuerySortOption.Order
    }

    var lastSuccessfulRequestParams: RequestParams?
}

enum SearchAction: BindableAction {
    case searchForManga
    case searchResultDownloaded(result: Result<Response<[Manga]>, APIError>, requestParams: SearchState.RequestParams)
    case searchStringChanged(String)

    case mangaThumbnailAction(UUID, MangaThumbnailAction)
    case filterAction(FiltersAction)

    case binding(BindingAction<SearchState>)
}

struct SearchEnvironment {
    var searchManga: (SearchState.RequestParams, JSONDecoder) -> Effect<Response<[Manga]>, APIError>
}

let searchReducer: Reducer<SearchState, SearchAction, SystemEnvironment<SearchEnvironment>> = .combine(
    // swiftlint:disable:next trailing_closure
    mangaThumbnailReducer
        .forEach(
            state: \.mangaThumbnailStates,
            action: /SearchAction.mangaThumbnailAction,
            environment: { _ in .live(
                environment: .init(
                    loadThumbnailInfo: downloadThumbnailInfo
                ),
                isMainQueueWithAnimation: false
            ) }
        ),
    // swiftlint:disable:next trailing_closure
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
                // if user clears the search string, we should delete all, what we've found for previous search request
                // and if user want to do the same request, e.g. only search string was used, no filters, it will be considered as
                // the same search request, and because of it we should also set 'nil' to lastRequestParams to avoid it
                guard !state.searchText.isEmpty else {
                    state.isSearchResultsDownloaded = true
                    let mangaIDs = state.mangaThumbnailStates.map(\.manga.id)
                    state.mangaThumbnailStates.removeAll()
                    state.lastSuccessfulRequestParams = nil
                    // cancelling all subscriptions to clear cache for manga(because all instance are already destroyed)
                    return .cancel(
                        ids: mangaIDs.map { CancelClearCacheForManga(mangaID: $0.id) }
                    )
                }
                
                let requestParams = SearchState.RequestParams(
                    searchQuery: state.searchText,
                    tags: state.filtersState.allTags.filter { $0.state != .notSelected },
                    // swiftlint:disable:next line_length
                    publicationDemographic: state.filtersState.publicationDemographics.filter { $0.state != .notSelected },
                    contentRatings: state.filtersState.contentRatings.filter { $0.state != .notSelected },
                    mangaStatuses: state.filtersState.mangaStatuses.filter { $0.state != .notSelected },
                    sortOption: state.searchSortOption,
                    sortOptionOrder: state.searchSortOptionOrder
                )
                
                guard requestParams != state.lastSuccessfulRequestParams else {
                    return .none
                }
                                
                // we remove all elements from 'mangaThumbnailStates' because MangaThumbnail loads data only after '.onAppear()' modifier was called
                // it also possible, that thumbnail was deinitialized, but because of SwiftUI it won't disapper, so it will no 'appear', it stays on the screen
                // and '.onAppear()' won't be called
                // so we remove everything here, then load items and if we got the same thumbnail as before, '.onAppear()' will fire
                state.mangaThumbnailStates = []
                state.isSearchResultsDownloaded = false
                
                return env.searchManga(requestParams, env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect { SearchAction.searchResultDownloaded(result: $0, requestParams: requestParams) }
                
            case .searchResultDownloaded(let result, let requestParams):
                switch result {
                    case .success(let response):
                        state.lastSuccessfulRequestParams = requestParams
                        state.isSearchResultsDownloaded = true
                        state.mangaThumbnailStates = []
                        state.mangaThumbnailStates = .init(
                            uniqueElements: response.data.map { MangaThumbnailState(manga: $0) }
                        )
                        return .none
                    case .failure(let error):
                        print("error on downloading search results \(error)")
                        return .none
                }
                
            case .binding:
                return Effect(value: SearchAction.searchForManga)
                
            case .filterAction:
                return .none
                
            case .mangaThumbnailAction:
                return .none
        }
    }
)
.binding()
