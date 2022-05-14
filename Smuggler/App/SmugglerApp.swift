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
