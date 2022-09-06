//
//  SearchBarView.swift
//  Hanami
//
//  Created by Oleg on 29/05/2022.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    let showDismisButton: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(searchText.isEmpty ? .theme.secondaryText : .white)
            
            TextField("Search", text: $searchText)
                .foregroundColor(.white)
                .accentColor(.white)
                .disableAutocorrection(true)
                .overlay(
                    Image(systemName: "xmark.circle.fill")
                        .padding()
                        .offset(x: 10)
                        .foregroundColor(.white)
                        .opacity((showDismisButton && !searchText.isEmpty) ? 1 : 0)
                        .onTapGesture {
                            UIApplication.shared.endEditing()
                            searchText = ""
                        },
                    alignment: .trailing
                )
        }
        .font(.headline)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}

struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SearchBarView(searchText: .constant(""), showDismisButton: true)
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
            
            SearchBarView(searchText: .constant(""), showDismisButton: false)
                .previewLayout(.sizeThatFits)
        }
    }
}
