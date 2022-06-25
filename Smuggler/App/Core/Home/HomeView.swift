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
                VStack {
                    ScrollView {
                        Text("oolxg")
                        LazyVStack(spacing: 0) {
                            if viewStore.mangaThumbnailStates.isEmpty {
                                ForEach(0..<20) { _ in
                                    MangaThumbnailSkeletonView()
                                        .padding()
                                }
                            }
                            
                            if !viewStore.mangaThumbnailStates.isEmpty {
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
                        .transition(.opacity)
                        .animation(.linear(duration: 0.7), value: viewStore.mangaThumbnailStates)
                        .navigationTitle("Smuggler")
                    }
                    .onAppear {
                        viewStore.send(.onAppear)
                }
                }
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
