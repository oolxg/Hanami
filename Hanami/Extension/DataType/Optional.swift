//
//  Optional.swift
//  Hanami
//
//  Created by Oleg on 27.12.22.
//

import Foundation

extension Optional {
    @inlinable var isNil: Bool {
        self == nil
    }
    
    @inlinable var hasValue: Bool {
        self != nil
    }
}
