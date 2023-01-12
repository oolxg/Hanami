//
//  Collection.swift
//  Hanami
//
//  Created by Oleg on 12.01.23.
//

import Foundation

extension Collection where Element: Identifiable {
    var idsSet: Set<Element.ID> {
        Set(map(\.id))
    }
}
