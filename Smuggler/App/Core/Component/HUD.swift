//
//  HUD.swift
//  Smuggler
//
//  Created by mk.pwnz on 03/07/2022.
//

import Foundation
import SwiftUI

struct HUD: View {
    let backgroundColor: Color
    let opacity: Double = 0.8
    let iconName: String?
    let text: String
    
    init(text: String, iconName: String? = nil, backgroundColor: Color) {
        self.text = text
        self.iconName = iconName
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        HStack {
            if let iconName = iconName {
                Image(systemName: iconName)
            }
            Text(text)
        }
        .padding(.horizontal, 12)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(backgroundColor)
                .opacity(opacity)
                .shadow(color: .black.opacity(0.25), radius: 35, x: 0, y: 5)
        )
    }
}

final class HUDState: ObservableObject {
    @Published var isPresented = false
    private(set) var text = ""
    private(set) var duration: Double = 5
    private(set) var iconName: String?
    private(set) var backgroundColor: Color = .theme.red
    
    static var shared = HUDState()
    
    private init () { }
    
    func show(text: String, iconName: String? = nil, withDuration duration: Double = 5, backgroundColor: Color = .theme.red) {
        self.text = text
        self.duration = duration
        self.iconName = iconName
        self.backgroundColor = backgroundColor
        withAnimation {
            isPresented = true
        }
    }
}
