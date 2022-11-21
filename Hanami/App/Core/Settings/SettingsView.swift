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
                Picker("Auto-lock", selection: viewStore.binding(\.$config.autolockPolicy)) {
                    ForEach(AutoLockPolicy.allCases) { policy in
                        Text(policy.value)
                            .tag(policy)
                    }
                }
                .pickerStyle(.menu)
                
                Slider(
                    value: viewStore.binding(\.$config.blurRadius),
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
                Toggle(
                    "Save manga in higher quality",
                    isOn: viewStore.binding(\.$config.useHigherQualityImagesForCaching)
                )
                
                Toggle(
                    "Read online manga in higher quality",
                    isOn: viewStore.binding(\.$config.useHigherQualityImagesForOnlineReading)
                )
                
                HStack {
                    Text("Hanami cache")
                    
                    Spacer()
                    
                    Text("\(viewStore.usedStorageSpace.clean()) MB")
                }
                
                if viewStore.usedStorageSpace > 0 {
                    Button(role: .destructive) {
                        viewStore.send(.clearMangaCache)
                    } label: {
                        Label("Delete all manga", systemImage: "trash")
                            .confirmationDialog(
                                store.scope(state: \.confirmationDialog),
                                dismiss: .cancelTapped
                            )
                    }
                }
            }
        } header: {
            Text("Storage and Network")
        }
    }
}
