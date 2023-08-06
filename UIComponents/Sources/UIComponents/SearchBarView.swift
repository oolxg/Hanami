//
//  SearchBarView.swift
//  Hanami
//
//  Created by Oleg on 29/05/2022.
//

import SwiftUI
import UITheme

public struct SearchBarView: View {
    @Binding private var searchText: String
    
    public init(searchText: Binding<String>) {
        self._searchText = searchText
    }
    
    public var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(searchText.isEmpty ? .theme.secondaryText : .theme.foreground)
            
            TextField("Search", text: $searchText)
                .foregroundColor(.theme.foreground)
                .accentColor(.theme.foreground)
                .disableAutocorrection(true)
            
             Image(systemName: "xmark")
                .opacity(searchText.isEmpty ? 0 : 1)
                .onTapGesture { searchText = "" }
        }
        .font(.headline)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.theme.foreground, lineWidth: 1)
        )
    }
}
