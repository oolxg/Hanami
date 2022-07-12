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
                    Text("by oolxg")
                    
                    ScrollView {
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
                    .transition(.opacity)
                }
                .navigationTitle("Smuggler")
                .navigationBarTitleDisplayMode(.large)
                .onAppear {
                    viewStore.send(.onAppear)
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
                environment: .init(
                    databaseClient: .live,
                    mangaClient: .live,
                    homeClient: .live
                )
            )
        )
    }
}
