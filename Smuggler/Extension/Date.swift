//
//  Date.swift
//  Smuggler
//
//  Created by mk.pwnz on 17/06/2022.
//

import Foundation

extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
