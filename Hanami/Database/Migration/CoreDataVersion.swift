//
//  CoreDataVersion.swift
//  CoreDataMigration-Example
//
//  Created by William Boles on 02/01/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import CoreData
import Utils

enum CoreDataMigrationVersion: String, CaseIterable {
    case version1 = "Model"
    case version2 = "Model2"
    case version3 = "Model3"

    static func current() throws -> CoreDataMigrationVersion {
        guard let latest = allCases.last else {
            throw AppError.databaseError("No model versions found.")
        }
        return latest
    }

    func nextVersion() -> CoreDataMigrationVersion? {
        switch self {
        case .version1:
            return .version2
        case .version2:
            return .version3
        case .version3:
            return nil
        }
    }
}
