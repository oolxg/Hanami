//
//  RootView.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct RootView: View {
    let store: Store<RootState, RootAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            TabView(selection: viewStore.binding(get: \.selectedTab, send: RootAction.tabChanged)) {
                HomeView(
                    store: store.scope(
                        state: \.homeState,
                        action: RootAction.homeAction
                    )
                )
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(RootState.Tab.home)
                
                SearchView(
                    store: store.scope(
                        state: \.searchState,
                        action: RootAction.searchAction
                    )
                )
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(RootState.Tab.search)
            }
        }
        .accentColor(.theme.accent)
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(
            store: .init(
                initialState: .init(selectedTab: .home),
                reducer: rootReducer,
                environment: .live(
                    environment: .init()
                )
            )
        )
    }
}