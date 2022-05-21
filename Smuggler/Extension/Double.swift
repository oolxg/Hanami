//
//  Double.swift
//  Smuggler
//
//  Created by mk.pwnz on 21/05/2022.
//

import Foundation

extension Double {
    var clean: String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
}
