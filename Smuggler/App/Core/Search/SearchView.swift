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
    @State private var showFilters: Bool = false
    
    var body: some View {
        NavigationView {
            WithViewStore(store) { viewStore in
                VStack {
                    HStack {
                        SearchBarView(searchText: viewStore.binding(get: \.searchText, send: SearchAction.searchStringChanged))
                        
                        filtersButton
                    }
                    
                    SortPickerView(
                        sortOption: viewStore.binding(\.$searchSortOption),
                        sortOptionOrder: viewStore.binding(\.$searchSortOptionOrder)
                    )
                    .padding(.horizontal)
                    .frame(width: UIScreen.main.bounds.width, alignment: .leading)
                    
                    searchResults

                }
            }
            .navigationTitle("Search")
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(
            store: .init(
                initialState: .init(),
                reducer: searchReducer,
                environment: .live(
                    environment: .init(
                        searchManga: makeMangaSearchRequest
                    ),
                    isMainQueueWithAnimation: true
                )
            )
        )
    }
}

extension SearchView {
    private var searchResults: some View {
        WithViewStore(store) { viewStore in
            if viewStore.shouldShowEmptyResultsMessage {
                VStack {
                    Text("Ehm, i found no manga")
                        .fontWeight(.medium)
                        .font(.title2)
                        .foregroundColor(.theme.accent)
                    Text("👉👈")
                }
                .padding()
                
                Spacer()
            } else {
                List {
                    ForEachStore(store.scope(state: \.mangaThumbnailStates, action: SearchAction.mangaThumbnailAction), content: MangaThumbnailView.init)
                }
            }
        }
    }
    
    private var filtersButton: some View {
        CircleButtonView(iconName: "slider.horizontal.3") {
            showFilters.toggle()
        }
        .padding(.trailing)
        .padding(.vertical)
        .sheet(isPresented: $showFilters) {
            FiltersView(store: store.scope(
                state: \.filtersState,
                action: SearchAction.filterAction)
            )
        }
    }
}

fileprivate struct SortPickerView: View {
    @Binding var sortOption: QuerySortOption
    @Binding var sortOptionOrder: QuerySortOption.Order
    
    var body: some View {
        Menu {
            makeButtonViewFor(sortOption: .relevance, order: .desc)
            
            Menu {
                makeButtonViewFor(sortOption: .latestUploadedChapter, order: .asc)
                makeButtonViewFor(sortOption: .latestUploadedChapter, order: .desc)
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
                .foregroundColor(.theme.accent)
                    .font(.callout)
                    .frame(width: 260, alignment: .leading)
                    
            }
        }
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
        }
    }
}
