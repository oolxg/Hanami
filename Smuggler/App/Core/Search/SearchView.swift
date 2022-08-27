//
//  SearchView.swift
//  Smuggler
//
//  Created by mk.pwnz on 27/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct SearchView: View {
    let store: Store<SearchState, SearchAction>
    @State private var showFilters = false
    
    var body: some View {
        NavigationView {
            WithViewStore(store) { viewStore in
                VStack {
                    searchOptions
                        .padding(.horizontal, 15)
                    
                    searchResults
                }
                .navigationTitle("Search")
                .sheet(isPresented: $showFilters, onDismiss: {
                    viewStore.send(.searchForManga)
                }, content: {
                    FiltersView(
                        store: store.scope(
                            state: \.filtersState,
                            action: SearchAction.filterAction
                        )
                    )
                })
                .searchable(text: viewStore.binding(\.$searchText), placement: .navigationBarDrawer)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showFilters.toggle()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .tint(.white)
                    }
                }
            }
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(
            store: .init(
                initialState: .init(),
                reducer: searchReducer,
                environment: .init(
                    databaseClient: .live,
                    mangaClient: .live,
                    searchClient: .live,
                    cacheClient: .live,
                    imageClient: .live,
                    hudClient: .live,
                    hapticClient: .live
                )
            )
        )
        .preferredColorScheme(.dark)
    }
}

extension SearchView {
    private var searchResults: some View {
        WithViewStore(store) { viewStore in
            VStack {
                if viewStore.shouldShowEmptyResultsMessage {
                    noFoundMangaView
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
                    if !viewStore.mangaThumbnailStates.isEmpty {
                        ForEachStore(
                            store.scope(
                                state: \.mangaThumbnailStates,
                                action: SearchAction.mangaThumbnailAction)
                        ) { thumbnailStore in
                            MangaThumbnailView(store: thumbnailStore)
                                .padding()
                        }
                        
                        if !viewStore.mangaThumbnailStates.isEmpty &&
                            viewStore.resultsCount != viewStore.mangaThumbnailStates.count {
                            Text("Only \(viewStore.mangaThumbnailStates.count) titles available")
                                .font(.headline)
                                .fontWeight(.black)
                                .padding()
                        }
                    }
                }
                .animation(.linear, value: viewStore.mangaThumbnailStates.isEmpty)
                .transition(.opacity)
            }
        }
    }
    
    @ViewBuilder private var noFoundMangaView: some View {
        VStack {
            Text("Ehm, i found no manga")
                .fontWeight(.medium)
                .foregroundColor(.theme.accent)
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
                .lineLimit(1)
                .font(.callout)
            }
            .accentColor(.white)
        }
    }
    
    private struct SortPickerView: View {
        @Binding var sortOption: QuerySortOption
        @Binding var sortOptionOrder: QuerySortOption.Order
        
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
            .accentColor(.white)
        }
        
        @ViewBuilder private func makeButtonViewFor(sortOption: QuerySortOption, order: QuerySortOption.Order) -> some View {
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
        private func getSortTypeName(sortOption: QuerySortOption, order: QuerySortOption.Order) -> String {
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
