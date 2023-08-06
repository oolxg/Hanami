//
//  Set.swift
//  Hanami
//
//  Created by Oleg on 15/09/2022.
//

import Foundation

public extension Set {
    mutating func removeAll(where predicate: (Element) throws -> Bool) rethrows {
        if let toDelete = try? self.filter(predicate) {
            self.subtract(toDelete)
        }
    }
    
    mutating func insertOrUpdateByID(_ value: Element) where Element: Identifiable {
        self.removeAll(where: { $0.id == value.id })
        self.insert(value)
    }
}
