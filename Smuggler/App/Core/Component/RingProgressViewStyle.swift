//
//  ActivityIndicator.swift
//  Smuggler
//
//  https://blckbirds.com/post/progress-bars-in-swiftui/
//

import Foundation
import SwiftUI


struct ActivityIndicator: View {
    @State private var degress = 0.0
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.4)
            .stroke(Color.theme.accent, lineWidth: 5.0)
            .frame(width: 120, height: 120)
            .rotationEffect(Angle(degrees: degress))
            .onAppear(perform: start)
    }
    
    func start() {
        _ = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            withAnimation {
                self.degress += 10.0
            }
            if self.degress == 360.0 {
                self.degress = 0.0
            }
        }
    }
}
