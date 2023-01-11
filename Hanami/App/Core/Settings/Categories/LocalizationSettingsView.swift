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
    @State private var languages = ISO639Language.allCases
    @State private var searchInput = ""
    @State private var showInfoPopover = false
    
    var body: some View {
        List {
            ForEach(languages) { lang in
                HStack {
                    Text(lang.language)
                        .onTapGesture {
                            selectedLanugauge = lang
                            dismiss()
                        }
                    
                    Spacer()
                    
                    if lang == selectedLanugauge {
                        Image(systemName: "checkmark")
                            .foregroundColor(.theme.accent)
                    }
                }
            }
        }
        .listStyle(.plain)
        .pickerStyle(.inline)
        .navigationTitle("Select manga language")
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.theme.foreground)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showInfoPopover = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.theme.foreground)
                }
            }
        }
        .alert(
            "This setting is needed to show relevant manga chapters if possible.\n" +
            "It does not change the language of the application.",
            isPresented: $showInfoPopover
        ) {
            Button("OK", role: .cancel) { showInfoPopover = false }
        }
        .searchable(
            text: $searchInput,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search language"
        )
        .onChange(of: searchInput) { _ in
            guard !searchInput.isEmpty else {
                languages = ISO639Language.allCases
                return
            }
            
            languages = ISO639Language.allCases.filter {
                $0.language.contains(searchInput)
            }
        }
    }
}

#if DEBUG
struct LocalizationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationSettingsView(selectedLanugauge: .constant(.id))
    }
}
#endif
