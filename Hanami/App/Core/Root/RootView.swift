//
//  RootView.swift
//  Hanami
//
//  Created by Oleg on 12/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct RootView: View {
    let store: Store<RootState, RootAction>
    @StateObject private var hudState = HUDClient.live
    
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
                
                DownloadsView(
                    store: store.scope(
                        state: \.downloadsState,
                        action: RootAction.downloadsAction
                    )
                )
                .tabItem {
                    Image(systemName: "square.and.arrow.down")
                    Text("Downloads")
                }
                .tag(RootState.Tab.downloads)
                
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
        .hud(
            isPresented: $hudState.isPresented,
            message: hudState.message,
            iconName: hudState.iconName,
            hideAfter: hudState.hideAfter,
            backgroundColor: hudState.backgroundColor
        )
        .accentColor(.theme.accent)
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
