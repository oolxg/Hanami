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
                        SearchBarView(searchText: viewStore.binding(get: \.searchText, send: SearchAction.searchStringChanged)
                        )
                        
                        CircleButtonView(iconName: "slider.horizontal.3") {
                            showFilters.toggle()
                            viewStore.send(.showFilterButtonWasTapped)
                        }
                        .padding(.trailing)
                        .padding(.vertical)
                        .popover(isPresented: $showFilters) {
                            List(viewStore.genres, id: \.self) { genre in
                                Text("\(genre.rawValue)")
                            }
                        }
                    }

                    List {
                        ForEachStore(store.scope(state: \.mangaThumbnailStates, action: SearchAction.mangaThumbnailAction), content: MangaThumbnailView.init)
                    }
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
                        searchManga: makeMangaSearchRequest,
                        getListOfTags: downloadTagsList
                    ),
                    isMainQueueWithAnimation: true
                )
            )
        )
    }
}
