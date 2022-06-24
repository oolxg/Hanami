//
//  View.swift
//  Smuggler
//
//  Created by mk.pwnz on 24/06/2022.
//

import Foundation
import SwiftUI

extension View {
    func redacted(if condition: @autoclosure () -> Bool) -> some View {
        redacted(reason: condition() ? .placeholder : [])
    }
}
