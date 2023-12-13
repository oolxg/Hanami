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
                    .contentShape(Rectangle())
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
    private var localizationSection: some View {
        Section {
            WithViewStore(store) { viewStore in
                HStack(spacing: 7) {
                    Text("Language for manga reading")
                    
                    Spacer()
                    
                    Group {
                        Text(viewStore.config.iso639Language.name)
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
                    LocalizationSettingsView(selectedLanugauge: viewStore.binding(\.$config.iso639Language))
                        .environment(\.colorScheme, colorScheme)
                }
                
                Picker("Reading format", selection: viewStore.binding(\.$config.readingFormat)) {
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
                Toggle(isOn: viewStore.binding(\.$config.useHigherQualityImagesForOnlineReading)) {
                    Label("Read online manga in higher quality", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.theme.foreground)
                }
                
                Toggle(isOn: viewStore.binding(\.$config.useHigherQualityImagesForCaching)) {
                    Label("Save manga in higher quality", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(.theme.foreground)
                }
                
                HStack {
                    Label("Saved manga size", systemImage: "folder.fill")
                        .foregroundColor(.theme.foreground)
                    
                    Spacer()
                    
                    Text("\(viewStore.usedStorageSpace.clean()) MB")
                }
                
                Button(role: .destructive) {
                    viewStore.send(.clearImageCacheButtonTapped)
                } label: {
                    Label("Clear image cache", systemImage: "photo.stack")
                        .foregroundColor(.red)
                }
                
                if viewStore.usedStorageSpace > 0 {
                    Button(role: .destructive) {
                        viewStore.send(.clearMangaCacheButtonTapped)
                    } label: {
                        Label("Delete all manga", systemImage: "trash")
                            .foregroundColor(.red)
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
    
    private var appearanceSection: some View {
        Section {
            WithViewStore(store) { viewStore in
                Picker("Theme", selection: viewStore.binding(\.$config.colorScheme)) {
                    Text("System").tag(0)
                    
                    Text("Light").tag(1)
                    
                    Text("Dark").tag(2)
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("Appearance")
        }
    }
}
