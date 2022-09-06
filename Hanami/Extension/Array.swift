//
//  RandomAccessCollection.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/07/2022.
//

import Foundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element: Hashable {
    func removeDuplicates() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

extension Array where Element == Int {
    func getAllSubsequences() -> [[Element]] {
        var result: [[Int]] = []
        var subsequence: [Int] = []
        
        let array = self.sorted()

        for element in array {
            if subsequence.isEmpty {
                subsequence.append(element)
            } else {
                if subsequence.last! + 1 == element {
                    subsequence.append(element)
                } else {
                    result.append(subsequence)
                    subsequence = [element]
                }
            }
            
            if subsequence.last! == array.last! {
                result.append(subsequence)
            }
        }
        
        return result
    }
}
