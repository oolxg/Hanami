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
        hideAfter hideInterval: Double,
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
}
