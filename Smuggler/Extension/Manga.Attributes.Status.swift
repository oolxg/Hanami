//
//  Manga.Attributes.Status.swift
//  Smuggler
//
//  Created by mk.pwnz on 08/07/2022.
//

import Foundation
import SwiftUI

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
