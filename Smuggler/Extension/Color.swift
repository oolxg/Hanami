//
//  Color.swift
//  Smuggler
//
//  Created by mk.pwnz on 29/05/2022.
//

import Foundation
import SwiftUI

extension Color {
    static let theme = ColorTheme()
}

struct ColorTheme {
    let accent = Color("AccentColor")
    let background = Color("BackgroundColor")
    let green = Color("GreenColor")
    let red = Color("RedColor")
    let secondaryText = Color("SecondaryTextColor")
    let darkGrey = Color("DarkGrey")
}
