//
//  UINavigationController.swift
//  Hanami
//
//  Created byOleg on 13/06/2022.
//

import Foundation
import SwiftUI


// this extension is to activate
// swipe right to return
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
