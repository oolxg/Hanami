//
//  ActivityIndicator.swift
//  Smuggler
//
//  https://blckbirds.com/post/progress-bars-in-swiftui/
//

import Foundation
import SwiftUI


struct ActivityIndicator: View {
    @State private var degrees1 = 0.0
    @State private var degrees2 = 0.0
    let lineWidth: Double
    
    init(lineWidth: Double = 4) {
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.0, to: 0.25)
                .stroke(Color.theme.green.opacity(0.7), lineWidth: lineWidth)
                .rotationEffect(Angle(degrees: degrees1), anchor: .center)
            
            Circle()
                .trim(from: 0.0, to: 0.4)
                .stroke(Color.theme.accent.opacity(0.7), lineWidth: lineWidth)
                .rotationEffect(Angle(degrees: degrees2), anchor: .center)
        }
        .onAppear {
            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                degrees1 += 360
            }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                degrees2 += 360
            }
        }
    }
}


struct ActivityIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ActivityIndicator()
            .frame(width: 200)
    }
}
