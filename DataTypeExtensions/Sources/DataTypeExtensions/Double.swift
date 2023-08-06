//
//  Double.swift
//  Hanami
//
//  Created by Oleg on 21/05/2022.
//

import Foundation

public extension Double {
    func clean(accuracy: Int = 1) -> String {
        let formatter = NumberFormatter()
        let number = NSNumber(value: self)
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = accuracy // maximum digits in Double after dot (maximum precision)
        formatter.decimalSeparator = "."
        return formatter.string(from: number)!
    }
    
    func reduceScale(to places: Int) -> Double {
        let multiplier = pow(10, Double(places))
        let newDecimal = multiplier * self
        let truncated = Double(Int(newDecimal))
        let originalDecimal = truncated / multiplier
        return originalDecimal
    }
}
