//
//  File.swift
//  
//
//  Created by Oleg on 02.09.23.
//

import Foundation

extension Task where Success == Never, Failure == Never {
    public static func sleep(seconds: Double) async throws {
        try await sleep(nanoseconds: UInt64(seconds * Double(NSEC_PER_SEC)))
    }
}
