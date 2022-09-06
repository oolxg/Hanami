//
//  Int.swift
//  Hanami
//
//  Created by Oleg on 18/06/2022.
//

import Foundation

extension Int {
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
                
            case 0...:
                return "\(self)"
                
            default:
                return "\(sign)\(self)"
        }
    }
}
