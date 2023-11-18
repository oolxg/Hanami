//
//  HUDClient.swift
//  Hanami
//
//  Created by Oleg on 11/08/2022.
//

import SwiftUI
import Dependencies
import UITheme

public extension DependencyValues {
    var hud: HUD {
        get { self[HUD.self] }
        set { self[HUD.self] = newValue }
    }
}

public final class HUD: ObservableObject, DependencyKey {
    @Published public var isPresented = false
    public private(set) var message = ""
    public private(set) var iconName: String?
    public private(set) var backgroundColor: Color = .theme.red
    private var workItem: DispatchWorkItem?
    
    public static let liveValue = HUD()
    
    private init () { }
    
    public func show(message: String, iconName: String? = nil, hideAfter: Double = 2.5, backgroundColor: Color = .theme.red) {
        self.message = message
        self.iconName = iconName
        self.backgroundColor = backgroundColor
        
        withAnimation {
            isPresented = true
        }
        
        workItem?.cancel()
        
        workItem = DispatchWorkItem {
            withAnimation {
                self.isPresented = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + hideAfter, execute: workItem!)
    }
}
