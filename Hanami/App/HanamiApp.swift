//
//  HanamiApp.swift
//  Hanami
//
//  Created by Oleg on 07/05/2022.
//

import SwiftUI
import ComposableArchitecture

@main
struct HanamiApp: App {
    let store: Store<AppState, AppAction> = .init(
        initialState: AppState(rootState: .init(selectedTab: .home)),
        reducer: appReducer,
        environment: .init(
            databaseClient: .live,
            hapticClient: .live,
            searchClient: .live,
            cacheClient: .live,
            imageClient: .live,
            mangaClient: .live,
            homeClient: .live,
            hudClient: .live
        )
    )
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
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
            .onAppear {
                ViewStore(store).send(.initApp)
            }
        }
    }
}
