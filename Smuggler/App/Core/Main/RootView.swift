//
//  RootView.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct RootView: View {
    let store: Store<AppState, AppAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            TabView(selection: viewStore.binding(get: \.selectedTab, send: AppAction.tabChanged)) {
                HomeView(store: store.scope(state: \.homeState, action: AppAction.homeAction))
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }
                    .tag(AppState.Tab.home)
                
                SearchView(store: store.scope(state: \.searchState, action: AppAction.searchAction))
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(AppState.Tab.search)
            }
            .accentColor(.theme.accent)
            .navigationViewStyle(StackNavigationViewStyle())
 
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(
            store: .init(
                initialState: .init(selectedTab: .home),
                reducer: appReducer,
                environment: .live(
                    environment: .init()
                )
            )
        )
    }
}
