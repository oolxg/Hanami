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
    let store: StoreOf<AppFeature> = .init(
        initialState: AppFeature.State(rootState: .init(selectedTab: .home)),
        reducer: AppFeature()
    )
    
    @Environment(\.colorScheme) private var colorScheme
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        appearance.backgroundColor = UIColor(Color.theme.background.opacity(0.65))
        
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
                    action: AppFeature.Action.rootAction
                )
            )
            .onAppear {
                ViewStore(store).send(.initApp)
            }
        }
    }
}
