//
//  SmugglerApp.swift
//  Smuggler
//
//  Created by mk.pwnz on 07/05/2022.
//

import SwiftUI
import ComposableArchitecture

@main
struct SmugglerApp: App {
    let store: Store<AppState, AppAction> = .init(
        initialState: AppState(rootState: .init(selectedTab: .home)),
        reducer: appReducer,
        environment: .init(
            databaseClient: .live,
            mangaClient: .live,
            homeClient: .live,
            searchClient: .live
        )
    )
    @ObservedObject private var viewStore: ViewStore<AppState, AppAction>
    
    init() {
        viewStore = ViewStore(store)
        viewStore.send(.initApp)
        
        UITabBar.appearance().backgroundColor = .black
        UITabBar.appearance().tintColor = .black
        UITabBar.appearance().barTintColor = .black
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(
                store: store.scope(
                    state: \.rootState,
                    action: AppAction.rootAction
                )
            )
        }
    }
}
