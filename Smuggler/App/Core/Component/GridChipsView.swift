//
//  GridChipsView.swift
//  Smuggler
//
//  Created by mk.pwnz on 30/05/2022.
//

import SwiftUI

struct GridChipsView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    private let data: Data
    @ViewBuilder private var content: (Data.Element) -> Content
    @State private var frameHeight: CGFloat = 20
    @Environment(\.presentationMode) var presentationMode

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.content = content
        self.data = data
    }

    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        var ids: [Data.Element] = []
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(data) { chipsData in
                    content(chipsData)
                        .padding(5)
                        .alignmentGuide(.leading) { dimension in
                            // if true, we move the item to the next line down
                            if abs(width - dimension.width) > geo.size.width {
                                width = 0
                                height -= dimension.height
                            }

                            let result = width

                            if chipsData.id == data.last!.id { // swiftlint:disable:this force_unwrapping
                                width = 0
                            } else {
                                width -= dimension.width
                            }

                            if result == 0 && !ids.contains(where: { $0.id == chipsData.id }) {
                                ids.append(chipsData)
                            }

                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height

                            if chipsData.id == data.last!.id { // swiftlint:disable:this force_unwrapping
                                height = 0
                            }
                            return result
                        }
                }
            }
        }
    }
}
