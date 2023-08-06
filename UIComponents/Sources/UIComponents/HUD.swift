//
//  HUD.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import Foundation
import SwiftUI

public struct HUD: View {
    private let backgroundColor: Color
    private let iconName: String?
    private let message: String
    
    public init(message: String, iconName: String? = nil, backgroundColor: Color) {
        self.message = message
        self.iconName = iconName
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            if let iconName {
                Image(systemName: iconName)
            }
            
            Text(message)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(backgroundColor)
                .opacity(0.8)
                .shadow(color: .black.opacity(0.25), radius: 35, x: 0, y: 5)
        )
    }
}
