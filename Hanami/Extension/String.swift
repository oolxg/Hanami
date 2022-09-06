//
//  String.swift
//  Smuggler
//
//  Created by mk.pwnz on 24/06/2022.
//

import Foundation

extension String {
    static func placeholder(length: Int) -> String {
        String(Array(repeating: "X", count: length))
    }
}
