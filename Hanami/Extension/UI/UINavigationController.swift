//
//  UINavigationController.swift
//  Hanami
//
//  Created by Oleg on 13/06/2022.
//

import SwiftUI

// this extension is to activate
// swipe right to return
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
