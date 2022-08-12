//
//  HUDClient.swift
//  Smuggler
//
//  Created by mk.pwnz on 11/08/2022.
//

import Foundation
import SwiftUI

final class HUDClient: ObservableObject {
    @Published var isPresented = false
    private(set) var message = ""
    private(set) var hideAfter = 2.5
    private(set) var iconName: String?
    private(set) var backgroundColor: Color = .theme.red
    
    static var live = HUDClient()
    
    private init () { }
    
    func show(message: String, iconName: String? = nil, hideAfter: Double = 2.5, backgroundColor: Color = .theme.red) {
        self.message = message
        self.hideAfter = hideAfter
        self.iconName = iconName
        self.backgroundColor = backgroundColor
        withAnimation {
            isPresented = true
        }
    }
}
