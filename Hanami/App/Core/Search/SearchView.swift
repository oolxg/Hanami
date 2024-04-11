//
//  SearchView.swift
//  Hanami
//
//  Created by Oleg on 27/05/2022.
//

import SwiftUI
import ComposableArchitecture
import UIComponents

// swiftlint:disable multiple_closures_with_trailing_closure
struct SearchView: View {
    let store: StoreOf<SearchFeature>
    let blurRadius: CGFloat
    @State private var showFilters = false
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isSearchFieldFocused: Bool
    
    private struct ViewState: Equatable {
        let searchTextEmpty: Bool
        let foundMangaCount: Int
        let searchResultsCount: Int
        let searchResultDidFetch: Bool
        let showEmptyResultsMessage: Bool
        let isLoading: Bool
        let showMangaList: Bool
        let searchHistory: IdentifiedArrayOf<SearchRequest>
        
        init(state: SearchFeature.State) {
            searchTextEmpty = state.searchText.isEmpty
            foundMangaCount = state.foundManga.count
            searchResultsCount = state.resultsCount
            searchResultDidFetch = state.searchResultDidFetch
            showEmptyResultsMessage = searchResultDidFetch && !searchTextEmpty && foundMangaCount == 0
            isLoading = state.isLoading
            searchHistory = state.searchHistory
            showMangaList = !isLoading && searchResultDidFetch && !showEmptyResultsMessage
        }
    }
    
    var body: some View {
        NavigationView {
            WithViewStore(store, observe: ViewState.init) { viewStore in
                VStack {
                    HStack {
                        searchBar
                        
                        if isSearchFieldFocused || !viewStore.searchTextEmpty {
                            Button("Cancel") {
                                viewStore.send(.cancelSearchButtonTapped)
                                UIApplication.shared.endEditing()
                            }
                            .foregroundColor(.theme.foreground)
                            .padding(.leading, 10)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut, value: isSearchFieldFocused || !viewStore.searchTextEmpty)
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 10)

                    searchOptions
                        .padding(.horizontal, 15)
                    
                    searchResults
                }
                .navigationTitle("Search")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showFilters.toggle()
                            UIApplication.shared.endEditing()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.theme.foreground)
                        }
                    }
                }
                .sheet(isPresented: $showFilters, onDismiss: {
                    viewStore.send(.searchForManga)
                }, content: {
                    FiltersView(
                        store: store.scope(
                            state: \.filtersState,
                            action: \.filtersAction
                        ),
                        blurRadius: blurRadius
                    )
                    .environment(\.colorScheme, colorScheme)
                })
            }
        }
    }
}

extension SearchView {
    @MainActor private var searchBar: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            SearchBarView(searchText: viewStore.$searchText)
                .focused($isSearchFieldFocused)
                .onTapGesture {
                    isSearchFieldFocused = true
                }
        }
    }
    
    private var searchResults: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack {
                if viewStore.showEmptyResultsMessage {
                    noFoundMangaView
                } else if viewStore.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .tint(.theme.accent)
                } else if viewStore.showMangaList {
                    mangaList
                } else {
                    searchHistory
                        .padding(.top, 10)
                }
            }
        }
    }
    
    @MainActor private var searchOptions: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            HStack {
                SortPickerView(
                    sortOption: viewStore.$searchSortOption,
                    sortOptionOrder: viewStore.$searchSortOptionOrder
                )
                
                Spacer()
                
                ResultsCountPicker(count: viewStore.$resultsCount)
            }
        }
    }
    
    private var searchHistory: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading) {
                HStack {
                    Text("Recently searched")
                        .fontWeight(.bold)

                    Spacer()
                    
                    if !viewStore.searchHistory.isEmpty {
                        Button {
                            viewStore.send(.userTappedOnDeleteSearchHistoryButton)
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.theme.foreground)
                        }
                    }
                }
                .font(.headline)
                
                ScrollView(showsIndicators: false) {
                    LazyVStack {
                        ForEach(viewStore.searchHistory) { searchRequest in
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                
                                Text(searchRequest.params.searchQuery)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(.rect)
                                    .onTapGesture {
                                        viewStore.send(.userTappedOnSearchHistory(searchRequest))
                                    }
                            }
                            
                            Rectangle()
                                .foregroundColor(.theme.foreground)
                                .frame(height: 0.8)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
    }
    
    private var mangaList: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ScrollView {
                VStack(spacing: 0) {
                    ForEachStore(
                        store.scope(
                            state: \.foundManga,
                            action: SearchFeature.Action.mangaThumbnailAction
                        )
                    ) { thumbnailStore in
                        MangaThumbnailView(
                            store: thumbnailStore,
                            blurRadius: blurRadius
                        )
                        .padding(5)
                    }
                    
                    if viewStore.foundMangaCount > 0 && viewStore.searchResultsCount != viewStore.foundMangaCount {
                        Text("Only \(viewStore.foundMangaCount) titles available")
                            .font(.headline)
                            .fontWeight(.black)
                            .padding()
                    }
                }
                .animation(.linear, value: viewStore.searchResultsCount)
                .transition(.opacity)
                
                if viewStore.searchResultDidFetch {
                    footer
                }
            }
        }
    }
    
    @ViewBuilder private var noFoundMangaView: some View {
        VStack {
            Text("Ehm, i found no manga")
                .fontWeight(.medium)
                .font(.title2)
            Text("👉👈")
        }
        .padding(.top, 100)
        
        Spacer()
    }
    
    private struct ResultsCountPicker: View {
        @Binding var count: Int
        
        var body: some View {
            Menu {
                Button("10") {
                    count = 10
                }
                
                Button("20") {
                    count = 20
                }
                
                Button("50") {
                    count = 50
                }
            } label: {
                HStack(spacing: 0) {
                    Text("Results: ")
                    Text("\(count)")
                        .fontWeight(.heavy)
                }
                .font(.callout)
            }
            .tint(.theme.foreground)
        }
    }
    
    private var footer: some View {
        HStack(spacing: 0) {
            Text("All information on this page provided by ")
            
            Text("MANGADEX")
                .fontWeight(.semibold)
        }
        .font(.caption2)
        .foregroundColor(.gray)
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
    
    private struct SortPickerView: View {
        @Binding var sortOption: FiltersFeature.QuerySortOption
        @Binding var sortOptionOrder: FiltersFeature.QuerySortOption.Order
        
        var body: some View {
            Menu {
                makeButtonViewFor(sortOption: .relevance, order: .desc)
                
                Menu {
                    makeButtonViewFor(sortOption: .rating, order: .desc)
                    makeButtonViewFor(sortOption: .rating, order: .asc)
                } label: {
                    if sortOption == .rating {
                        Image(systemName: "checkmark")
                    }
                    Text("Rating")
                }
                
                Menu {
                    makeButtonViewFor(sortOption: .latestUploadedChapter, order: .desc)
                    makeButtonViewFor(sortOption: .latestUploadedChapter, order: .asc)
                } label: {
                    if sortOption == .latestUploadedChapter {
                        Image(systemName: "checkmark")
                    }
                    Text("Upload")
                }
                
                Menu {
                    makeButtonViewFor(sortOption: .title, order: .asc)
                    makeButtonViewFor(sortOption: .title, order: .desc)
                } label: {
                    if sortOption == .title {
                        Image(systemName: "checkmark")
                    }
                    Text("Title")
                }
                
                Menu {
                    makeButtonViewFor(sortOption: .createdAt, order: .desc)
                    makeButtonViewFor(sortOption: .createdAt, order: .asc)
                } label: {
                    if sortOption == .createdAt {
                        Image(systemName: "checkmark")
                    }
                    Text("When added")
                }
                
                Menu {
                    makeButtonViewFor(sortOption: .followedCount, order: .asc)
                    makeButtonViewFor(sortOption: .followedCount, order: .desc)
                } label: {
                    if sortOption == .followedCount {
                        Image(systemName: "checkmark")
                    }
                    Text("Followers count")
                }
                
                Menu {
                    makeButtonViewFor(sortOption: .year, order: .desc)
                    makeButtonViewFor(sortOption: .year, order: .asc)
                } label: {
                    if sortOption == .year {
                        Image(systemName: "checkmark")
                    }
                    Text("Year")
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Sort by")
                        Text(getSortTypeName(sortOption: sortOption, order: sortOptionOrder))
                            .fontWeight(.heavy)
                    }
                    .font(.callout)
                    .frame(height: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .tint(.theme.foreground)
        }
        
        @ViewBuilder private func makeButtonViewFor(sortOption: FiltersFeature.QuerySortOption, order: FiltersFeature.QuerySortOption.Order) -> some View {
            Button {
                self.sortOptionOrder = order
                self.sortOption = sortOption
            } label: {
                HStack {
                    if self.sortOption == sortOption && self.sortOptionOrder == order {
                        Image(systemName: "checkmark")
                    }
                    
                    Text(getSortTypeName(sortOption: sortOption, order: order))
                }
            }
        }
        
        // swiftlint:disable:next cyclomatic_complexity
        private func getSortTypeName(sortOption: FiltersFeature.QuerySortOption, order: FiltersFeature.QuerySortOption.Order) -> String {
            switch sortOption {
            case .relevance:
                return "Relevance"
            case .latestUploadedChapter:
                if order == .desc {
                    return "Latest upload"
                } else {
                    return "Oldest upload"
                }
            case .title:
                if order == .desc {
                    return "Title descending"
                } else {
                    return "Title ascending"
                }
            case .createdAt:
                if order == .desc {
                    return "Recently added"
                } else {
                    return "Oldest added"
                }
            case .followedCount:
                if order == .desc {
                    return "Most followers"
                } else {
                    return "Fewest followers"
                }
            case .year:
                if order == .desc {
                    return "Year descending"
                } else {
                    return "Year ascending"
                }
            case .rating:
                if order == .desc {
                    return "Highest rating"
                } else {
                    return "Lowest rating"
                }
            }
        }
    }
}
// swiftlint:enable multiple_closures_with_trailing_closure
