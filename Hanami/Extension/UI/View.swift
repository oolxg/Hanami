//
//  View.swift
//  Hanami
//
//  Created by Oleg on 24/06/2022.
//

import Foundation
import SwiftUI

extension View {
    func redacted(if condition: @autoclosure () -> Bool) -> some View {
        redacted(reason: condition() ? .placeholder : []).shimmering(active: condition())
    }
    
    func hud(
        isPresented: Binding<Bool>,
        message: String,
        iconName: String? = nil,
        backgroundColor: Color
    ) -> some View {
        ZStack(alignment: .top) {
            self
            
            if isPresented.wrappedValue {
                HUD(message: message, iconName: iconName, backgroundColor: backgroundColor)
                    .zIndex(1)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.height < 0 {
                                // if swipe up - dismiss HUD
                                withAnimation {
                                    isPresented.wrappedValue = false
                                }
                            }
                        }
                    )
            }
        }
    }
    
    func autoBlur(radius: Double) -> some View {
        blur(radius: radius)
            .allowsHitTesting(radius < 1)
            .animation(.linear(duration: 0.1), value: radius)
    }
    
    /// Adds an animated shimmering effect to any view, typically to show that
    /// an operation is in progress.
    /// - Parameters:
    ///   - active: Convenience parameter to conditionally enable the effect. Defaults to `true`.
    ///   - duration: The duration of a shimmer cycle in seconds. Default: `1.5`.
    ///   - bounce: Whether to bounce (reverse) the animation back and forth. Defaults to `false`.
    ///   - delay:A delay in seconds. Defaults to `0`.
    @ViewBuilder func shimmering(
        active: Bool = true, duration: Double = 1.5, bounce: Bool = false, delay: Double = 0
    ) -> some View {
        if active {
            modifier(Shimmer(duration: duration, bounce: bounce, delay: delay))
        } else {
            self
        }
    }
}
