//
//  ExpandableForEach.swift
//  Smuggler
//
//  Created by mk.pwnz on 21/05/2022.
//

import SwiftUI

struct ExpandableForEach<Data, Content>: View where Data: RandomAccessCollection,
                                                    Content: View, Data.Element: Identifiable {
    @State private var isExpanded = false
    private let items: Data
    private let title: String
    private let action: (Bool) -> Void
    @ViewBuilder private var content: (Data.Element) -> Content
    
    /// - Parameters:
    ///  - title: Title, that will be show on top of ExpandableForEach
    ///  - Items: List of items inside of ExpandableForEach
    ///  - onListExpansion: Action, that will be called each time, when list expanded or folded
    ///  - content: Each row inside the ExpandableForEach
    init(title: String, items: Data, onListExpansion: @escaping (Bool) -> Void = { _ in }, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.content = content
        self.action = onListExpansion
        self.title = title
    }
    
    var body: some View {
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
        .onChange(of: isExpanded, perform: action)
        .buttonStyle(PlainButtonStyle())
        .padding()
        .frame(maxWidth: .infinity)
    }
}
