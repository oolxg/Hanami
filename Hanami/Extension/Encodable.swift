//
//  Encodable.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import Foundation

extension Encodable {
    func toData() -> Data? {
        try? AppUtil.encoder.encode(self)
    }
}
