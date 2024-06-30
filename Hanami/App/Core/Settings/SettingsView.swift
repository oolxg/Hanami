//
//  SettingsView.swift
//  Hanami
//
//  Created by Oleg on 10/10/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher
import Utils
import ModelKit

// swiftlint:disable multiple_closures_with_trailing_closure
struct SettingsView: View {
    let store: StoreOf<SettingsFeature>
    @State private var showLocalizationView = false
    @State private var showAboutSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            List {
                localizationSection
                
                privacySection
                
                appearanceSection
                
                storageSection
                
                Text("About")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                    .onTapGesture { showAboutSheet.toggle() }
                    .sheet(isPresented: $showAboutSheet) {
                        AboutView()
                            .environment(\.colorScheme, colorScheme)
                    }
            }
            .navigationTitle("Settings")
            .tint(Color.theme.accent)
            .listStyle(.insetGrouped)
        }
    }
}

extension SettingsView {
    @MainActor private var localizationSection: some View {
        Section {
            WithViewStore(store, observe: { $0 }) { viewStore in
                HStack(spacing: 7) {
                    Text("Manga Language")
                    
                    Spacer()
                    
                    Group {
                        Text(viewStore.readingLanguage.name)
                            .foregroundColor(.theme.accent)
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 12)
                            .foregroundColor(.theme.accent)
                    }
                    .onTapGesture { showLocalizationView = true }
                }
                .fullScreenCover(isPresented: $showLocalizationView) {
                    LocalizationSettingsView(selectedLanugauge: viewStore.$readingLanguage)
                        .environment(\.colorScheme, colorScheme)
                }
                
                Picker("Reading Format", selection: viewStore.$readingFormat) {
                    ForEach(SettingsConfig.ReadingFormat.allCases, id: \.self) { readingFormat in
                        Text(readingFormat.rawValue).tag(readingFormat)
                    }
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("Reading")
        }
    }
    
    @MainActor private var privacySection: some View {
        Section {
            WithViewStore(store, observe: { $0 }) { viewStore in
                Picker("Lock App", selection: viewStore.$autolockPolicy) {
                    ForEach(AutoLockPolicy.allCases) { policy in
                        Text(policy.value)
                            .tag(policy)
                    }
                }
                .pickerStyle(.menu)
                
                Slider(
                    value: viewStore.$blurRadius,
                    in: Defaults.Security.minBlurRadius...Defaults.Security.maxBlurRadius,
                    step: Defaults.Security.blurRadiusStep,
                    minimumValueLabel: Image(systemName: "eye"),
                    maximumValueLabel: Image(systemName: "eye.slash"),
                    label: EmptyView.init
                )
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Lock App: Require Face ID to enter App\nSlider: Blur Level when App is Inactive")
        }
    }
    
    
    @MainActor private var storageSection: some View {
        Section {
            WithViewStore(store, observe: { $0 }) { viewStore in
                Toggle(isOn: viewStore.$useHigherQualityImagesForOnlineReading) {
                    Label("Read in HQ", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.theme.foreground)
                }
                
                Toggle(isOn: viewStore.$useHigherQualityImagesForCaching) {
                    Label("Save in HQ", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(.theme.foreground)
                }
                
                HStack {
                    Label("Downloads", systemImage: "folder")
                        .foregroundColor(.theme.foreground)
                    
                    Spacer()
                    
                    Text("\(viewStore.usedStorageSpace.clean()) MB")
                }
                
                Button(role: .destructive) {
                    viewStore.send(.clearImageCacheButtonTapped)
                } label: {
                    Label("Clear Image Cache", systemImage: "photo.stack")
                        .foregroundColor(.red)
                }
                
                if viewStore.usedStorageSpace > 0 {
                    Button(role: .destructive) {
                        viewStore.send(.clearMangaCacheButtonTapped)
                    } label: {
                        Label("Delete All Mangas", systemImage: "trash")
                            .foregroundColor(.red)
                            .confirmationDialog(
                                store: store.scope(
                                    state: \.$confirmationDialog,
                                    action: \.confirmationDialog
                                )
                            )
                    }
                }
            }
        } header: {
            Text("Storage and Network")
        } footer: {
            Text("Read Online or Save in Higher Quality\nClear Cache doesn't remove Downloaded Mangas")
        }
    }
    
    @MainActor private var appearanceSection: some View {
        Section {
            WithViewStore(store, observe: { $0 }) { viewStore in
                Picker("Theme", selection: viewStore.$colorScheme) {
                    Text("System").tag(SettingsConfig.ColorScheme.default)
                    
                    Text("Light").tag(SettingsConfig.ColorScheme.light)
                    
                    Text("Dark").tag(SettingsConfig.ColorScheme.dark)
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("Appearance")
        }
    }
}
// swiftlint:enable multiple_closures_with_trailing_closure
