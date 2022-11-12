//
//  Manga.Attributes.Status.swift
//  Hanami
//
//  Created by Oleg on 08/07/2022.
//

import struct SwiftUI.Color

extension Manga.Attributes.Status {
    var color: Color {
        switch self {
        case .completed:
            return .blue
        case .ongoing:
            return .green
        case .cancelled:
            return .red
        case .hiatus:
            return .red
        }
    }
}
