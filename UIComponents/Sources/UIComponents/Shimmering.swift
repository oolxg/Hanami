//
//  Shimmer.swift
//
//  Created by Vikram Kriplaney on 23.03.21.
//
// From: https://github.com/markiv/SwiftUI-Shimmer/blob/main/Sources/Shimmer/Shimmer.swift

import SwiftUI

/// A view modifier that applies an animated "shimmer" to any view, typically to show that
/// an operation is in progress.
public struct Shimmer: ViewModifier {
    let animation: Animation
    @State private var phase: CGFloat = 0
    
    /// Initializes his modifier with a custom animation,
    /// - Parameter animation: A custom animation. The default animation is
    ///   `.linear(duration: 1.5).repeatForever(autoreverses: false)`.
    public init(animation: Animation = Self.defaultAnimation) {
        self.animation = animation
    }

    /// The default animation effect.
    public static let defaultAnimation = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)

    /// Convenience, backward-compatible initializer.
    /// - Parameters:
    ///   - duration: The duration of a shimmer cycle in seconds. Default: `1.5`.
    ///   - bounce: Whether to bounce (reverse) the animation back and forth. Defaults to `false`.
    ///   - delay:A delay in seconds. Defaults to `0`.
    public init(duration: Double = 1.5, bounce: Bool = false, delay: Double = 0) {
        self.animation = .linear(duration: duration)
            .repeatForever(autoreverses: bounce)
            .delay(delay)
    }

    public func body(content: Content) -> some View {
        content
            .modifier(
                AnimatedMask(phase: phase).animation(animation)
            )
            .onAppear { phase = 0.8 }
    }

    /// An animatable modifier to interpolate between `phase` values.
    struct AnimatedMask: AnimatableModifier {
        var phase: CGFloat = 0

        var animatableData: CGFloat {
            get { phase }
            set { phase = newValue }
        }

        func body(content: Content) -> some View {
            content
                .mask(GradientMask(phase: phase).scaleEffect(3))
        }
    }

    /// A slanted, animatable gradient between transparent and opaque to use as mask.
    /// The `phase` parameter shifts the gradient, moving the opaque band.
    struct GradientMask: View {
        let phase: CGFloat
        let centerColor = Color.black
        let edgeColor = Color.black.opacity(0.3)
        
        var body: some View {
            LinearGradient(
                gradient:
                    Gradient(
                        stops: [
                            .init(color: edgeColor, location: phase),
                            .init(color: centerColor, location: phase + 0.1),
                            .init(color: edgeColor, location: phase + 0.2)
                        ]
                    ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
