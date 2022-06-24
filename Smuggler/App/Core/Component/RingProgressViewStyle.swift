//
//  RingProgressViewStyle.swift
//  Smuggler
//
//  https://swiftuirecipes.com/blog/custom-progress-view-in-swiftui
//

import Foundation
import SwiftUI

public struct RingProgressViewStyle: ProgressViewStyle {
    private let defaultSize: CGFloat = 36
    private let lineWidth: CGFloat = 6
    private let defaultProgress = 0.2 // CHANGE
    
    // tracks the rotation angle for the indefinite progress bar
    @State private var fillRotationAngle = Angle.degrees(180) // ADD
    
    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        VStack {
            configuration.label
            progressCircleView(
                fractionCompleted: configuration.fractionCompleted ?? defaultProgress,
                isIndefinite: configuration.fractionCompleted == nil
            ) // UPDATE
            configuration.currentValueLabel
        }
    }
    
    private func progressCircleView(fractionCompleted: Double, isIndefinite: Bool) -> some View { // UPDATE
            // this is the circular "track", which is a full circle at all times
        Circle()
            .strokeBorder(Color.gray.opacity(0.5), lineWidth: lineWidth, antialiased: true)
            .overlay(fillView(fractionCompleted: fractionCompleted, isIndefinite: isIndefinite)) // UPDATE
            .frame(width: defaultSize, height: defaultSize)
    }
    
    private func fillView(fractionCompleted: Double, isIndefinite: Bool) -> some View { // UPDATE
        Circle() // the fill view is also a circle
            .trim(from: 0, to: CGFloat(fractionCompleted))
            .stroke(Color.theme.accent, lineWidth: lineWidth)
            .frame(width: defaultSize - lineWidth, height: defaultSize - lineWidth)
            .rotationEffect(fillRotationAngle) // UPDATE
            // triggers the infinite rotation animation for indefinite progress views
            .onAppear {
                if isIndefinite {
                    withAnimation(.easeInOut(duration: 1).repeatForever()) {
                        fillRotationAngle = .degrees(-90)
                    }
                }
            }
    }
}
