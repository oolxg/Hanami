//
//  SearchView.swift
//  Hanami
//
//  Created by Oleg on 27/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct SearchView: View {
    let store: StoreOf<SearchFeature>
    let blurRadius: CGFloat
    @State private var showFilters = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            WithViewStore(store) { viewStore in
                VStack {
                    HStack {
                        SearchBarView(searchText: viewStore.binding(\.$searchText))
                            .focused($isSearchFieldFocused)
                            .onTapGesture {
                                isSearchFieldFocused = true
                            }
                        
                        if isSearchFieldFocused || !viewStore.searchText.isEmpty {
                            Button("Cancel") {
                                viewStore.send(.resetSearch)
                                UIApplication.shared.endEditing()
                            }
                            .foregroundColor(.white)
                            .padding(.leading, 10)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut, value: isSearchFieldFocused || !viewStore.searchText.isEmpty)
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
                                .foregroundColor(.white)
                        }
                    }
                }
                .sheet(isPresented: $showFilters, onDismiss: {
                    viewStore.send(.searchForManga)
                }, content: {
                    FiltersView(
                        store: store.scope(
                            state: \.filtersState,
                            action: SearchFeature.Action.filtersAction
                        ),
                        blurRadius: blurRadius
                    )
                })
            }
        }
    }
}

#if DEBUG
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(
            store: .init(
                initialState: .init(),
                reducer: SearchFeature()._printChanges()
            ),
            blurRadius: 0
        )
        .preferredColorScheme(.dark)
    }
}
#endif

extension SearchView {
    private var searchResults: some View {
        WithViewStore(store) { viewStore in
            VStack {
                if viewStore.shouldShowEmptyResultsMessage {
                    noFoundMangaView
                } else if viewStore.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .tint(.theme.accent)
                } else {
                    mangaList
                }
            }
        }
    }
    
    private var searchOptions: some View {
        WithViewStore(store) { viewStore in
            HStack {
                SortPickerView(
                    sortOption: viewStore.binding(\.$searchSortOption),
                    sortOptionOrder: viewStore.binding(\.$searchSortOptionOrder)
                )
                
                Spacer()
                
                ResultsCountPicker(count: viewStore.binding(\.$resultsCount))
            }
        }
    }
    
    private var mangaList: some View {
        WithViewStore(store.actionless) { viewStore in
            ScrollView {
                VStack(spacing: 0) {
                    ForEachStore(
                        store.scope(
                            state: \.searchResults,
                            action: SearchFeature.Action.mangaThumbnailAction
                        )
                    ) { thumbnailStore in
                        MangaThumbnailView(
                            store: thumbnailStore,
                            blurRadius: blurRadius
                        )
                        .padding(5)
                    }
                    
                    if !viewStore.searchResults.isEmpty && viewStore.resultsCount != viewStore.searchResults.count {
                        Text("Only \(viewStore.searchResults.count) titles available")
                            .font(.headline)
                            .fontWeight(.black)
                            .padding()
                    }
                }
                .animation(.linear, value: viewStore.searchResults.isEmpty)
                .transition(.opacity)
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
            .tint(.white)
        }
    }
    
    private struct SortPickerView: View {
        @Binding var sortOption: FilterFeature.QuerySortOption
        @Binding var sortOptionOrder: FilterFeature.QuerySortOption.Order
        
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
                    
                    HStack(spacing: 0) {
                        Text("Sort by ")
                        Text(getSortTypeName(sortOption: sortOption, order: sortOptionOrder))
                            .fontWeight(.heavy)
                    }
                    .font(.callout)
                    .frame(width: 200, height: 20, alignment: .leading)
                }
                .padding(.trailing)
            }
            .tint(.white)
        }
        
        @ViewBuilder private func makeButtonViewFor(sortOption: FilterFeature.QuerySortOption, order: FilterFeature.QuerySortOption.Order) -> some View {
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
        private func getSortTypeName(sortOption: FilterFeature.QuerySortOption, order: FilterFeature.QuerySortOption.Order) -> String {
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
