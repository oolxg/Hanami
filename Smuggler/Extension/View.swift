//
//  View.swift
//  Smuggler
//
//  Created by mk.pwnz on 24/06/2022.
//

import Foundation
import SwiftUI

extension View {
    func redacted(if condition: @autoclosure () -> Bool) -> some View {
        redacted(reason: condition() ? .placeholder : [])
    }
    
    @ViewBuilder func hidden(_ hidden: Bool) -> some View {
        if !hidden {
            self
        }
    }
    
    func hud(
        isPresented: Binding<Bool>,
        message: String,
        iconName: String? = nil,
        transition: AnyTransition = .move(edge: .top).combined(with: .opacity),
        hideAfter hideInterval: Double,
        backgroundColor: Color
    ) -> some View {
        ZStack(alignment: .top) {
            self
            
            if isPresented.wrappedValue {
                HUD(text: message, iconName: iconName, backgroundColor: backgroundColor)
                    .zIndex(1)
                    .transition(transition)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + hideInterval) {
                            withAnimation {
                                isPresented.wrappedValue = false
                            }
                        }
                    }
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
}
