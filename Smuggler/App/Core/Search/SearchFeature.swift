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
    
    var isFilterPopoverPresented: Bool = false
    
    var searchText: String = ""
    var searchSortOption: QuerySortOption = .relevance
    var searchSortOptionOrder: QuerySortOption.Order = .desc
    
    var publicationDemographic: [Manga.Attributes.PublicationDemographic] = []
    var contentRatings: [Manga.Attributes.ContentRatings] = []
    var publicationStatus: [Manga.Attributes.Status] = []
    
    // All the types defined inside one enum
    var genres: [Tag.Attributes.TagName.Name] = []
    var themeTypes: [Tag.Attributes.TagName.Name] = []
    var formatTypes: [Tag.Attributes.TagName.Name] = []
    var contentTypes: [Tag.Attributes.TagName.Name] = []
}

enum SearchAction: Equatable {
    case searchForManga
    case showFilterButtonWasTapped
    case filterListDownloaded(Result<Response<[Tag]>, APIError>)
    case searchResultDownloaded(Result<Response<[Manga]>, APIError>)
    case mangaThumbnailAction(UUID, MangaThumbnailAction)
    case searchStringChanged(String)
}

struct SearchEnvironment {
    var searchManga: (String, QuerySortOption, QuerySortOption.Order, JSONDecoder) -> Effect<Response<[Manga]>, APIError>
    var getListOfTags: () -> Effect<Response<[Tag]>, APIError>
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
    Reducer { state, action, env in
        switch action {
            case .searchStringChanged(let query):
                struct DebounceForSearch: Hashable { }
                
                state.searchText = query
                return Effect(value: SearchAction.searchForManga)
                    .debounce(id: DebounceForSearch(), for: 0.8, scheduler: env.mainQueue())
                    .eraseToEffect()
            case .searchForManga:
                guard !state.searchText.isEmpty else { return .none }
                return env.searchManga(state.searchText, state.searchSortOption, state.searchSortOptionOrder, env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(SearchAction.searchResultDownloaded)
            case .searchResultDownloaded(let result):
                switch result {
                    case .success(let response):
                        state.mangaThumbnailStates = .init(uncheckedUniqueElements: response.data.map { MangaThumbnailState(manga: $0) })
                        return .none
                    case .failure(let error):
                        print("error on downloading search results \(error)")
                        return .none
                }
            case .showFilterButtonWasTapped:
                return env.getListOfTags()
                    .receive(on: env.mainQueue())
                    .catchToEffect(SearchAction.filterListDownloaded)
            case .filterListDownloaded(let result):
                switch result {
                    case .success(let response):
                        for tag in response.data {
                            switch tag.attributes.group {
                                case .theme:
                                    state.themeTypes.append(tag.attributes.name.en)
                                case .content:
                                    state.contentTypes.append(tag.attributes.name.en)
                                case .format:
                                    state.formatTypes.append(tag.attributes.name.en)
                                case .genre:
                                    state.genres.append(tag.attributes.name.en)
                            }
                        }
                        return .none
                    case .failure(let error):
                        print("error on downloading tags list \(error)")
                        return .none
                }
            case .mangaThumbnailAction(_, _):
                return .none

        }
    }
)
