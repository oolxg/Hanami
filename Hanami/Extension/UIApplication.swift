//
//  UIApplication.swift
//  Smuggler
//
//  Created by mk.pwnz on 29/05/2022.
//

import Foundation
import SwiftUI

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
