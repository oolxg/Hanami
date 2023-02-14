//
//  SettingsView.swift
//  Hanami
//
//  Created by Oleg on 10/10/2022.
//

import SwiftUI
import ComposableArchitecture
import NukeUI

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>
    @State private var showLocalizationView = false
    @State private var showAboutSheet = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationView {
            VStack {
                Text("by oolxg")
                    .font(.caption2)
                    .frame(height: 0)
                    .foregroundColor(.clear)
                
                List {
                    localizationSection
                    
                    readingSection
                    
                    privacySection
                    
                    appearanceSection
                    
                    storageSection
                    
                    Text("About")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { showAboutSheet.toggle() }
                        .sheet(isPresented: $showAboutSheet) {
                            aboutSectionSheet
                                .environment(\.colorScheme, colorScheme)
                        }
                }
                .navigationTitle("Settings")
                .tint(Color.theme.accent)
                .listStyle(.insetGrouped)
            }
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
    private var localizationSection: some View {
        Section {
            WithViewStore(store) { viewStore in
                HStack(spacing: 7) {
                    Text("Language for manga reading")
                    
                    Spacer()
                    
                    Text(viewStore.config.iso639Language.name)
                        .foregroundColor(.theme.accent)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 12)
                        .foregroundColor(.theme.accent)
                }
                .contentShape(Rectangle())
                .onTapGesture { showLocalizationView = true }
                .fullScreenCover(isPresented: $showLocalizationView) {
                    LocalizationSettingsView(selectedLanugauge: viewStore.binding(\.$config.iso639Language))
                        .environment(\.colorScheme, colorScheme)
                }
            }
        } header: {
            Text("Localization")
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
    
    @MainActor private var aboutSectionSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack {
                        LazyImage(url: Defaults.Links.githubAvatarLink)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .onTapGesture { openURL(Defaults.Links.githubUserLink) }
                        
                        Text("Hey-hey 🖖, my name is Oleg!")
                    }
                    
                    Rectangle()
                        .foregroundColor(.theme.secondaryText)
                        .frame(height: 1.5)
                    
                    Text(
                        LocalizedStringKey(
                            // swiftlint:disable line_length
                            "This project uses MangaDEX API to fetch manga, descriptions, etc., that you can find in the app. " +
                            "Since this is a completely **non-commercial** project, development may not go as fast as desired. " +
                            "If you want to participate in the development, for example, add the localization of the " +
                            "application, a new feature, or just help financially, you can do it using the links below."
                            // swiftlint:enable line_length
                        )
                    )

                    VStack {
                        Image("bmc-violet")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .onTapGesture { openURL(Defaults.Links.bmcLink) }
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .frame(width: 200, height: 70)
                            .overlay {
                                HStack(spacing: 5) {
                                    Image("gh-mark-white")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 35)
                                    
                                    Image("gh-logo-white")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 35)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .onTapGesture { openURL(Defaults.Links.githubProjectLink) }
                    }
                    
                    VStack(spacing: 5) {
                        Text("From 🇩🇪 with ❤️")
                            .foregroundColor(.theme.secondaryText)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("Version: \(AppUtil.version)")
                            .foregroundColor(.theme.secondaryText)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("About")
            .padding(.horizontal)
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
    
    private var readingSection: some View {
        Section {
            WithViewStore(store) { viewStore in
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
}
