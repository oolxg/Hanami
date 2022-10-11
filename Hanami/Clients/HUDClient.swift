//
//  HUDClient.swift
//  Hanami
//
//  Created by Oleg on 11/08/2022.
//

import Foundation
import SwiftUI
import ComposableArchitecture

extension DependencyValues {
    var hudClient: HUDClient {
        get { self[HUDClient.self] }
        set { self[HUDClient.self] = newValue }
    }
}

final class HUDClient: ObservableObject, DependencyKey {
    @Published var isPresented = false
    private(set) var message = ""
    private(set) var hideAfter = 2.5
    private(set) var iconName: String?
    private(set) var backgroundColor: Color = .theme.red
    
    static var liveValue = HUDClient()
    static var testValue: HUDClient {
        fatalError("Unimplemented")
    }
    
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
