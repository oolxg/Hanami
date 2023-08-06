//
//  Collection.swift
//  Hanami
//
//  Created by Oleg on 12.01.23.
//

import Foundation

public extension Collection where Element: Identifiable {
    var ids: Set<Element.ID> {
        Set(map(\.id))
    }
}
