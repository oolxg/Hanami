//
//  ExpandableList.swift
//  Smuggler
//
//  Created by mk.pwnz on 21/05/2022.
//

import SwiftUI

struct ExpandableList<Data, Content>: View where Data : RandomAccessCollection, Content : View, Data.Element : Identifiable {
    @State private var isExpanded: Bool = false
    let title: String
    let items: Data
    @ViewBuilder var content: (Data.Element) -> Content
    
    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(items) { item in
                    content(item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text(title)
                    .font(.title3)
                    .fontWeight(.heavy)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.5), value: isExpanded)
        .transition(.opacity)
    }
    
    private var header: some View {
        HStack {
            Text(title)
                .fontWeight(.bold)
                .font(.title2)
        }
        .padding(.vertical, 4)
        .onTapGesture { isExpanded.toggle() }
    }
}
struct ExpandableList_Previews: PreviewProvider {
    static var previews: some View {
        ExpandableList(title: "Chapter 12.3", items: [dev.manga]) { item in
            HStack {
                Image(systemName: "heart")
                Text(item.id.uuidString)
            }
        }
    }
}
