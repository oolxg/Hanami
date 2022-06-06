//
//  CircleButtonView.swift
//  Smuggler
//
//  Created by mk.pwnz on 29/05/2022.
//

import SwiftUI

struct CircleButtonView: View {
    let iconName: String
    let action: () -> Void
    
    init(iconName: String, _ action: @escaping () -> Void) {
        self.iconName = iconName
        self.action = action
    }
    
    var body: some View {
        Image(systemName: iconName)
            .font(.headline)
            .foregroundColor(.theme.accent)
            .frame(width: 60, height: 60)
            .background(
                Circle()
                    .foregroundColor(.theme.background)
            )
            .shadow(
                color: .theme.accent.opacity(0.25),
                radius: 10,
                x: 0,
                y: 0
            )
            .onTapGesture(perform: action)
    }
}

struct CircleButtonView_Previews: PreviewProvider {
    static var previews: some View {
        CircleButtonView(iconName: "heart.fill") {
        }
    }
}
