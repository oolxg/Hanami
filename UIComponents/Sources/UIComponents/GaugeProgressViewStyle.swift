//
//  GaugeProgressViewStyle.swift
//  Hanami
//
//  https://www.hackingwithswift.com/quick-start/swiftui/customizing-progressview-with-progressviewstyle
//

import Foundation
import SwiftUI
import UITheme

public struct GaugeProgressStyle: ProgressViewStyle {
    private let strokeColor: Color
    
    public init(strokeColor: Color) {
        self.strokeColor = strokeColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(Color.theme.darkGray)

            Circle()
                .trim(from: 0, to: configuration.fractionCompleted ?? 0)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2]))
                .rotationEffect(.degrees(-90))
        }
    }
}
