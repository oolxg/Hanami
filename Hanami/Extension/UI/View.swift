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
        redacted(reason: condition() ? .placeholder : [])
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
    
    @ViewBuilder func offset(completion: @escaping (CGRect) -> Void) -> some View {
        self
            .overlay {
                GeometryReader { geo in
                    let rect = geo.frame(in: .named("SCROLLER"))
                    Color.clear
                        .preference(key: OffsetKey.self, value: rect)
                        .onPreferenceChange( OffsetKey.self) { newValue in
                            completion(newValue)
                        }
                }
            }
    }
    
    func autoBlur(radius: Double) -> some View {
        blur(radius: radius)
            .allowsHitTesting(radius < 1)
            .animation(.linear(duration: 0.1), value: radius)
    }
}

private struct OffsetKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
