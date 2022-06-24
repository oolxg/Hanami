//
//  Double.swift
//  Smuggler
//
//  Created by mk.pwnz on 21/05/2022.
//

import Foundation

extension Double {
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
    
    var abbreviation: String {
        let num = abs(Double(self))
        let sign = (self < 0) ? "-" : ""
        
        switch num {
            case 1_000_000_000...:
                var formatted = num / 1_000_000_000
                formatted = formatted.reduceScale(to: 1)
                return "\(sign)\(formatted)B"
                
            case 1_000_000...:
                var formatted = num / 1_000_000
                formatted = formatted.reduceScale(to: 1)
                return "\(sign)\(formatted)M"
                
            case 1_000...:
                var formatted = num / 1_000
                formatted = formatted.reduceScale(to: 1)
                return "\(sign)\(formatted)K"
                
            default:
                return "\(sign)\(self)"
        }
    }
}
