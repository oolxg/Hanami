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
        HStack(alignment: .center) {
            if let iconName = iconName {
                Image(systemName: iconName)
            }
            
            Text(text)
                .multilineTextAlignment(.center)
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

struct HUDInfo: Equatable {
    var show = false
    var message = ""
    var iconName: String?
    var backgroundColor = Color.theme.red
}
