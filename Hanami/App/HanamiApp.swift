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
    
    struct ViewState: Equatable {
        let colorScheme: ColorScheme
        
        init(state: AppFeature.State) {
            switch state.rootState.settingsState.config.colorScheme {
            case 1:
                colorScheme = .light
            case 2:
                colorScheme = .dark
            default:
                colorScheme = .dark
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            WithViewStore(store, observe: ViewState.init) { viewStore in
                RootView(
                    store: store.scope(
                        state: \.rootState,
                        action: AppFeature.Action.rootAction
                    )
                )
                .environment(\.colorScheme, viewStore.colorScheme)
                .onAppear {
                    viewStore.send(.initApp)
                }
            }
        }
    }
}
