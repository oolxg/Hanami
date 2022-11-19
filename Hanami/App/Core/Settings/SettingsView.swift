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
            List {
                privacySection
                
                storageSection
            }
            .navigationTitle("Settings")
            .tint(Color.theme.accent)
        }
    }
}

#if DEBUG
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
#endif

extension SettingsView {
    private var privacySection: some View {
        Section {
            WithViewStore(store) { viewStore in
                Picker("Auto-lock", selection: viewStore.binding(\.$autolockPolicy)) {
                    ForEach(AutoLockPolicy.allCases) { policy in
                        Text(policy.value)
                            .tag(policy)
                    }
                }
                .pickerStyle(.menu)
                
                Slider(
                    value: viewStore.binding(\.$blurRadius),
                    in: Defaults.Security.minBlurRadius...Defaults.Security.maxBlurRadius,
                    step: Defaults.Security.blurRadiusStep,
                    minimumValueLabel: Image(systemName: "eye"),
                    maximumValueLabel: Image(systemName: "eye.slash"),
                    label: EmptyView.init
                )
            }
        } header: {
            Text("Privacy")
        }
    }
    
    private var storageSection: some View {
        Section {
            WithViewStore(store) { viewStore in
                Toggle("Save manga in high resolution", isOn: viewStore.binding(\.$useHighResImagesForCaching))
                
                Toggle(
                    "Read online manga in high resolution",
                    isOn: viewStore.binding(\.$useHighResImagesForOnlineReading)
                )
                
                HStack {
                    Text("Hanami cache")
                    
                    Spacer()
                    
                    Text("\(viewStore.usedStorageSize.clean()) MB")
                }
                
                Button(role: .destructive) {
                    viewStore.send(.clearMangaCache)
                } label: {
                    Label("Clear cache", systemImage: "trash")
                }
            }
        } header: {
            Text("Storage Usage")
        }
    }
}
