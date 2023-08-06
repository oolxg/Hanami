//
//  String.swift
//  Hanami
//
//  Created by Oleg on 24/06/2022.
//

import Foundation

public extension String {
    static func placeholder(length: Int) -> String {
        String(Array(repeating: "X", count: length))
    }
}
