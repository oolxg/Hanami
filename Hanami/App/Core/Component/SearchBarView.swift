//
//  SearchBarView.swift
//  Hanami
//
//  Created by Oleg on 29/05/2022.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(searchText.isEmpty ? .theme.secondaryText : .white)
            
            TextField("Search", text: $searchText)
                .foregroundColor(.white)
                .accentColor(.white)
                .disableAutocorrection(true)
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
            SearchBarView(searchText: .constant(""))
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
            
            SearchBarView(searchText: .constant(""))
                .previewLayout(.sizeThatFits)
        }
    }
}
