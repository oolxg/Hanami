//
//  PersistenceController.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import CoreData

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
    func prepare(completion: @escaping (Result<Void, AppError>) -> Void) {
        do {
           try loadPersistentStore(completion: completion)
        } catch {
            completion(.failure(error as? AppError ?? .databaseError("Failed to load PersistentStore")))
        }
    }
    func rebuild(completion: @escaping (Result<Void, AppError>) -> Void) {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            completion(.failure(.databaseError("PersistentContainer was not set up properly.")))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try NSPersistentStoreCoordinator.destroyStore(at: storeURL)
            } catch {
                completion(.failure(error as? AppError ?? .databaseError("Migration error occurred")))
            }
            container.loadPersistentStores { _, error in
                guard error == nil else {
                    let message = "Was unable to load store \(String(describing: error))."
                    completion(.failure(.databaseError(message)))
                    return
                }
                completion(.success(()))
            }
        }
    }
    private func loadPersistentStore(completion: @escaping (Result<Void, AppError>) -> Void) throws {
        try migrateStoreIfNeeded { result in
            switch result {
            case .success:
                container.loadPersistentStores { _, error in
                    guard error == nil else {
                        let message = "Was unable to load store \(String(describing: error))."
                        completion(.failure(.databaseError(message)))
                        return
                    }
                    completion(.success(()))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    private func migrateStoreIfNeeded(completion: @escaping (Result<Void, AppError>) -> Void) throws {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            throw AppError.databaseError("PersistentContainer was not set up properly.")
        }

        if try migrator.requiresMigration(at: storeURL, toVersion: try CoreDataMigrationVersion.current()) {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try migrator.migrateStore(at: storeURL, toVersion: try CoreDataMigrationVersion.current())
                } catch {
                    completion(.failure(error as? AppError ?? .databaseError(nil)))
                }
                completion(.success(()))
            }
        } else {
            completion(.success(()))
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
