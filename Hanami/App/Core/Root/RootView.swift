//
//  RootView.swift
//  Hanami
//
//  Created by Oleg on 12/05/2022.
//

import SwiftUI
import ComposableArchitecture
import HUD
import Utils

struct RootView: View {
    let store: StoreOf<RootFeature>
    @StateObject private var hud = HUD.liveValue
    @Environment(\.scenePhase) private var scenePhase
    
    private struct ViewState: Equatable {
        let selectedTab: RootFeature.Tab
        let blurRadius: CGFloat
        
        init(state: RootFeature.State) {
            selectedTab = state.selectedTab
            blurRadius = state.isAppLocked ? state.settingsState.blurRadius : Defaults.Security.minBlurRadius
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            TabView(selection: viewStore.binding(get: \.selectedTab, send: RootFeature.Action.tabChanged)) {
                HomeView(
                    store: store.scope(
                        state: \.homeState,
                        action: RootFeature.Action.homeAction
                    ),
                    blurRadius: viewStore.blurRadius
                )
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(RootFeature.Tab.home)
                
                DownloadsView(
                    store: store.scope(
                        state: \.downloadsState,
                        action: RootFeature.Action.downloadsAction
                    ),
                    blurRadius: viewStore.blurRadius
                )
                .tabItem {
                    Image("DownloadsFolderIcon")
                        .resizable()
                    Text("Downloads")
                }
                .tag(RootFeature.Tab.downloads)
                
                SearchView(
                    store: store.scope(
                        state: \.searchState,
                        action: RootFeature.Action.searchAction
                    ),
                    blurRadius: viewStore.blurRadius
                )
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(RootFeature.Tab.search)
                
                SettingsView(
                    store: store.scope(
                        state: \.settingsState,
                        action: RootFeature.Action.settingsAction
                    )
                )
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(RootFeature.Tab.settings)
            }
            .hud(
                isPresented: $hud.isPresented,
                message: hud.message,
                iconName: hud.iconName,
                backgroundColor: hud.backgroundColor
            )
            .autoBlur(radius: viewStore.blurRadius)
            .onChange(of: scenePhase) { viewStore.send(.scenePhaseChanged($0)) }
        }
        .accentColor(.theme.accent)
        .navigationViewStyle(.stack)
    }
}
