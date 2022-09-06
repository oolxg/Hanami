//
//  UITabBar.swift
//  Hanami
//
//  Created by AliMert
//  https://github.com/AliMert/HidableTabView-SwiftUI
//

import Foundation
import SwiftUI

// swiftlint:disable all
public extension UITabBar {
    // if tab View is used get tabBar 'isHidden' parameter value
    static func isHidden(_ completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.windows.first { $0.isKeyWindow }?.allSubviews().forEach { view in
                if let view = view as? UITabBar {
                    completion(view.isHidden)
                }
            }
        }
    }
    
    // if tab View is used toogle Tab Bar Visibility
    static func toggleTabBarVisibility(animated: Bool = true) {
        UITabBar.isHidden { isHidden in
            if isHidden {
                UITabBar.showTabBar(animated: animated)
            } else {
                UITabBar.hideTabBar(animated: animated)
            }
        }
    }
    
    // if tab View is used show Tab Bar
    static func showTabBar(animated: Bool = true) {
        DispatchQueue.main.async {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.windows.first { $0.isKeyWindow }?.allSubviews().forEach { view in
                if let view = view as? UITabBar {
                    view.setIsHidden(false, animated: animated)
                }
            }
        }
    }
    
    // if tab View is used hide Tab Bar
    static func hideTabBar(animated: Bool = true) {
        DispatchQueue.main.async {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.windows.first { $0.isKeyWindow }?.allSubviews().forEach { view in
                if let view = view as? UITabBar {
                    view.setIsHidden(true, animated: animated)
                }
            }
        }
    }
    
    // logic is implemented for hiding or showing the tab bar with animation
    private func setIsHidden(_ hidden: Bool, animated: Bool) {
        let isViewHidden = self.isHidden
        
        if animated {
            if self.isHidden && !hidden {
                self.isHidden = false
                self.frame.origin.y = UIScreen.main.bounds.height + 200
            }
            
            if isViewHidden && !hidden {
                self.alpha = 0.0
            }
            
            UIView.animate(withDuration: 0.5, animations: {
                self.alpha = hidden ? 0.0 : 1.0
            })
            UIView.animate(withDuration: 0.4, animations: {
                if !isViewHidden && hidden {
                    self.frame.origin.y = UIScreen.main.bounds.height + 200
                } else if isViewHidden && !hidden {
                    self.frame.origin.y = UIScreen.main.bounds.height - self.frame.height
                }
            }) { _ in
                if hidden && !self.isHidden {
                    self.isHidden = true
                }
            }
        } else {
            if !isViewHidden && hidden {
                self.frame.origin.y = UIScreen.main.bounds.height + 200
            } else if isViewHidden && !hidden {
                self.frame.origin.y = UIScreen.main.bounds.height - self.frame.height
            }
            self.isHidden = hidden
            self.alpha = 1
        }
    }
}


extension UIView {
    func allSubviews() -> [UIView] {
        var allSubviews = subviews
        for subview in subviews {
            allSubviews.append(contentsOf: subview.allSubviews())
        }
        return allSubviews
    }
}


public extension View {
    func showTabBar(animated: Bool = true) -> some View {
        return self.modifier(ShowTabBar(animated: animated))
    }
    func hideTabBar(animated: Bool = true) -> some View {
        return self.modifier(HiddenTabBar(animated: animated))
    }
    
    func shouldHideTabBar(_ hidden: Bool, animated: Bool = true) -> AnyView {
        if hidden {
            return AnyView(hideTabBar(animated: animated))
        } else {
            return AnyView(showTabBar(animated: animated))
        }
    }
}


struct ShowTabBar: ViewModifier {
    var animated = true
    func body(content: Content) -> some View {
        return content.padding(.zero).onAppear {
            UITabBar.showTabBar(animated: animated)
        }
    }
}


struct HiddenTabBar: ViewModifier {
    var animated = true
    
    func body(content: Content) -> some View {
        return content.padding(.zero).onAppear {
            UITabBar.hideTabBar(animated: animated)
        }
    }
}
