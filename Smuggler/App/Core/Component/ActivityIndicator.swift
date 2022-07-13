//
//  ActivityIndicator.swift
//  Smuggler
//
//  https://blckbirds.com/post/progress-bars-in-swiftui/
//

import Foundation
import SwiftUI


struct ActivityIndicator: View {
    @State private var degrees1 = Double.random(in: 0..<360)
    @State private var degrees2 = Double.random(in: 0..<360)
    let lineWidth: Double
    
    init(lineWidth: Double = 4) {
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .trim(from: 0.0, to: 0.25)
                    .stroke(Color.theme.green.opacity(0.7), lineWidth: lineWidth)
                    .rotationEffect(Angle(degrees: degrees1), anchor: .center)
                    .frame(width: geo.size.width * 0.85, height: geo.size.height * 0.85, alignment: .center)
                
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
}


struct ActivityIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ActivityIndicator()
            .frame(width: 200)
    }
}
