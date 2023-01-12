//
//  LocalizationSettingsView.swift
//  Hanami
//
//  Created by Oleg on 11.01.23.
//

import SwiftUI
import ComposableArchitecture

struct LocalizationSettingsView: View {
    @Binding var selectedLanugauge: ISO639Language
    @Environment(\.dismiss) private var dismiss
    @State private var allLanguages = ISO639Language.allCases.sorted { $0.language < $1.language }
    @State private var searchInput = ""
    @State private var showInfoAlert = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(allLanguages) { lang in
                    HStack {
                        Text(lang.language)
                        
                        Spacer()
                        
                        if lang == selectedLanugauge {
                            Image(systemName: "checkmark")
                                .foregroundColor(.theme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedLanugauge = lang
                        dismiss()
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select manga language")
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.theme.foreground)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInfoAlert = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.theme.foreground)
                    }
                }
            }
            .alert(
                "This setting is needed to show relevant manga chapters if possible.\n" +
                "It does not change the language of the application.",
                isPresented: $showInfoAlert
            ) {
                Button("OK", role: .cancel) { showInfoAlert = false }
            }
            .searchable(
                text: $searchInput,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search language"
            )
            .onChange(of: searchInput) { _ in
                guard !searchInput.isEmpty else {
                    allLanguages = ISO639Language.allCases.sorted { $0.language < $1.language }
                    return
                }
                
                allLanguages = ISO639Language.allCases.filter { $0.language.contains(searchInput) }
                    .sorted { $0.language < $1.language }
            }
        }
    }
}

#if DEBUG
struct LocalizationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationSettingsView(selectedLanugauge: .constant(.zhRo))
    }
}
#endif
