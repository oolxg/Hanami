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
            searchClient: .live,
            cacheClient: .live,
            imageClient: .live,
            hudClient: .live
        )
    )
    
    @ObservedObject private var viewStore: ViewStore<AppState, AppAction>
    
    init() {
        viewStore = ViewStore(store)
        viewStore.send(.initApp)
        
        let appearance = UITabBarAppearance()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
        appearance.backgroundColor = UIColor(Color.black.opacity(0.1))
        
        // Use this appearance when scrolling behind the TabView:
        UITabBar.appearance().standardAppearance = appearance
        // Use this appearance when scrolled all the way up:
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
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
