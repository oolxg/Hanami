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
        WithViewStore(store) { viewStore in
            NavigationView {
                VStack {
                    Text("asdad")
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEachStore(
                                store.scope(
                                    state: \.mangaThumbnailStates,
                                    action: HomeAction.mangaThumbnailAction
                                )
                            ) { thumbnailViewStore in
                                MangaThumbnailView(store: thumbnailViewStore)
                                    .padding()
                            }
                        }
                    }
                    .navigationTitle("Smuggler")
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
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
                        loadHomePage: downloadMangaList,
                        fetchStatistics: fetchMangaStatistics
                    )
                )
            )
        )
    }
}
