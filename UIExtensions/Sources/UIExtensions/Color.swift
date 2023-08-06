//
//  Color.swift
//  Hanami
//
//  Created by Oleg on 29/05/2022.
//

import struct SwiftUI.Color

public extension Color {
    static let theme = ColorTheme()
}

public struct ColorTheme {
    public let accent = Color("AccentColor")
    public let background = Color("BackgroundColor")
    public let foreground = Color("ForegroundColor")
    public let green = Color("GreenColor")
    public let yellow = Color("YellowColor")
    public let red = Color("RedColor")
    public let secondaryText = Color("SecondaryTextColor")
    public let darkGray = Color("DarkGrey")
}
