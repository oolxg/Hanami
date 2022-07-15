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
                HUD(text: message, iconName: iconName, backgroundColor: backgroundColor)
                    .zIndex(1)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal)
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
