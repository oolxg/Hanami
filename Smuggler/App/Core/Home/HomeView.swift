//
//  HomeView.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: Store<HomeState, HomeAction>

    var body: some View {
        NavigationView {
            WithViewStore(store) { viewStore in
                List {
                    Text(viewStore.mangaThumbnailStates.count.description)
                    ForEachStore(store.scope(state: \.mangaThumbnailStates, action: HomeAction.mangaThumbnailActon)) { thumbnailViewStore in
                        MangaThumbnailView(store: thumbnailViewStore)
                    }
                }
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .refreshable {
                    viewStore.send(.refresh)
                }
            }
            .navigationTitle("Smuggler")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            store: .init(
                initialState: HomeState(),
                reducer: homeReducer,
                environment: .live(
                    environment: .init(
                        loadHomePage: downloadMangaList
                    )
                )
            )
        )
    }
}
