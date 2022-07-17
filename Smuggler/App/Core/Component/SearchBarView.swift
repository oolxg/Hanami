//
//  SearchBarView.swift
//  Smuggler
//
//  Created by mk.pwnz on 29/05/2022.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(searchText.isEmpty ? .theme.secondaryText : .theme.accent)
            
            TextField("Type something...", text: $searchText)
                .foregroundColor(.theme.accent)
                .disableAutocorrection(true)
                .keyboardType(.alphabet)
                .overlay(
                    Image(systemName: "xmark.circle.fill")
                        .padding()
                        .offset(x: 10)
                        .foregroundColor(.theme.accent)
                        .opacity(searchText.isEmpty ? 0 : 1)
                        .onTapGesture {
                            UIApplication.shared.endEditing()
                            searchText = ""
                        },
                    alignment: .trailing
                )
        }
        .font(.headline)
        .padding()
        .background(RoundedRectangle(cornerRadius: 25)
            .fill(Color.theme.background)
            .shadow(
                color: .theme.accent.opacity(0.3),
                radius: 10,
                x: 0.0,
                y: 0.0
            )
        )
    }
}

struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SearchBarView(searchText: .constant(""))
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
            
            SearchBarView(searchText: .constant(""))
                .previewLayout(.sizeThatFits)
        }
    }
}
