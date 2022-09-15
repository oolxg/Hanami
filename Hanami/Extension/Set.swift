//
//  Set.swift
//  Hanami
//
//  Created by Oleg on 15/09/2022.
//

import Foundation

extension Set {
    mutating func remove(where predicate: (Element) throws -> Bool) rethrows {
        if let toDelete = try? self.filter(predicate) {
            self.subtract(toDelete)
        }
    }
    
    mutating func insertOrUpdate(_ value: Element) where Element: Identifiable {
        self.remove(where: { $0.id == value.id })
        self.insert(value)
    }
}
