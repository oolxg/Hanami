//
//  PersistenceController.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import CoreData
import Utils
import ModelKit

struct PersistenceController {
    static let shared = PersistenceController()
    private let migrator = CoreDataMigrator()
    
    let container: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Model")
        let description = container.persistentStoreDescriptions.first
        description?.shouldInferMappingModelAutomatically = false
        description?.shouldMigrateStoreAutomatically = false
        return container
    }()
}

extension PersistenceController {
    @discardableResult
    func prepare() async -> Result<Void, AppError> {
        await loadPersistentStore()
    }
    
    @discardableResult
    func rebuild() async -> Result<Void, AppError> {
        await withCheckedContinuation { continuation in
            Task {
                guard let storeURL = container.persistentStoreDescriptions.first?.url else {
                    continuation.resume(
                        returning: .failure(.databaseError("PersistentContainer was not set up properly."))
                    )
                    return
                }
                
                do {
                    try NSPersistentStoreCoordinator.destroyStore(at: storeURL)
                } catch {
                    continuation.resume(
                        returning: .failure(error as? AppError ?? .databaseError("Migration error occurred"))
                    )
                }
                container.loadPersistentStores { _, error in
                    guard error.isNil else {
                        let message = "Was unable to load store \(String(describing: error))."
                        continuation.resume(returning: .failure(.databaseError(message)))
                        return
                    }
                    continuation.resume(returning: .success(()))
                }
            }
        }
    }
    
    private func loadPersistentStore() async -> Result<Void, AppError> {
        let result = await migrateStoreIfNeeded()
        
        switch result {
        case .success:
            return await withCheckedContinuation { continuation in
                container.loadPersistentStores { _, error in
                    guard error.isNil else {
                        let message = "Was unable to load store \(String(describing: error))."
                        continuation.resume(returning: .failure(.databaseError(message)))
                        return
                    }
                    continuation.resume(returning: .success(()))
                }
            }
        case .failure:
            return result
        }
    }
    
    private func migrateStoreIfNeeded() async -> Result<Void, AppError> {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            return .failure(.databaseError("PersistentContainer was not set up properly."))
        }
        
        guard let currentVersion = try? CoreDataMigrationVersion.current() else {
            return .failure(.databaseError("Failed to get current CoreData migration version."))
        }
        
        if migrator.requiresMigration(at: storeURL, toVersion: currentVersion) {
            return await withCheckedContinuation { continuation in
                Task {
                    do {
                        try migrator.migrateStore(
                            at: storeURL,
                            toVersion: currentVersion
                        )
                        continuation.resume(returning: .success(()))
                    } catch {
                        continuation.resume(returning: .failure(error as? AppError ?? .databaseError(nil)))
                    }
                }
            }
        } else {
            return .success(())
        }
    }
}
protocol ManagedObjectConvertible {
    associatedtype ManagedObject: NSManagedObject
    associatedtype RelationshipMO
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext, withRelationships: RelationshipMO?) -> ManagedObject
}

protocol IdentifiableMO: NSManagedObject {
    var id: UUID { get set }
}
