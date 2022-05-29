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
    
    init() {
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor(.theme.accent)]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor(.theme.accent)]
    }
    
    var body: some Scene {
        WindowGroup {
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
}
