//
//  RangeReplaceableCollection.swift
//  Smuggler
//
//  Created by mk.pwnz on 21/05/2022.
//

import Foundation

extension RangeReplaceableCollection {
    public mutating func resize(_ size: Int, fillWith value: Iterator.Element) {
        if count < size {
            append(contentsOf: repeatElement(value, count: count.distance(to: size)))
        } else if count > size {
            let newEnd = index(startIndex, offsetBy: size)
            removeSubrange(newEnd ..< endIndex)
        }
    }
}
