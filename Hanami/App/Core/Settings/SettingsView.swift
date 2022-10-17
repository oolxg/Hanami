//
//  SettingsView.swift
//  Hanami
//
//  Created by Oleg on 10/10/2022.
//

import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>
    
    var body: some View {
        NavigationView {
            WithViewStore(store) { viewStore in
                List {
                    Section {
                        Picker("Auto-lock", selection: viewStore.binding(\.$autoLockPolicy)) {
                            ForEach(AutoLockPolicy.allCases) { policy in
                                Text(policy.value)
                                    .tag(policy)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text("Privacy")
                    }
                }
            }
            .navigationTitle("Settings")
            .tint(Color.theme.accent)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            store: Store(
                initialState: SettingsFeature.State(),
                reducer: SettingsFeature()._printChanges()
            )
        )
    }
}
