//
//  LazyView.swift
//  Hanami
//
//  Created by chriseidhof
//  https://gist.github.com/chriseidhof/d2fcafb53843df343fe07f3c0dac41d5
//

import SwiftUI

struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}
struct LazyView_Previews: PreviewProvider {
    static var previews: some View {
        LazyView(EmptyView())
    }
}
