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
                    Text("\(viewStore.downloadedManga.count)")
                    List {
                        ForEachStore(store.scope(state: \.downloadedManga, action: HomeAction.mangaActon)) { manga in
                            WithViewStore(manga) { m in
                                Text(m.state.attributes.title.en ?? "NOT DEFINED")
                            }
                        }
                    }
                }
                .onAppear {
                    viewStore.send(.onAppear)
                }
                
                
            }
            .navigationTitle("Smuggler")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(store: .init(initialState: HomeState(), reducer: homeReducer, environment: .live(environment: .init(loadHomePage: homeEffect, decoder: { JSONDecoder() }))))
    }
}
