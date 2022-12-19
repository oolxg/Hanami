//
//  Color.swift
//  Hanami
//
//  Created by Oleg on 29/05/2022.
//

import struct SwiftUI.Color

extension Color {
    static let theme = ColorTheme()
}

struct ColorTheme {
    let accent = Color("AccentColor")
    let background = Color("BackgroundColor")
    let foreground = Color("ForegroundColor")
    let green = Color("GreenColor")
    let yellow = Color("YellowColor")
    let red = Color("RedColor")
    let secondaryText = Color("SecondaryTextColor")
    let darkGray = Color("DarkGrey")
}
