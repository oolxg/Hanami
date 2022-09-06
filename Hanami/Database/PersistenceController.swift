//
//  PersistenceController.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import Foundation
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
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
        container.loadPersistentStores { _, error in
            guard error == nil else {
                completion(.failure(.databaseError("Unable to load store: \(String(describing: error)).")))
                return
            }
            completion(.success(()))
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
                completion(.failure(.databaseError("Failed to destroy Database.")))
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
}

protocol ManagedObjectProtocol {
    associatedtype Entity
    func toEntity() -> Entity
}

protocol ManagedObjectConvertible {
    associatedtype ManagedObject: NSManagedObject, ManagedObjectProtocol
    associatedtype RelationshipMO
    @discardableResult
    func toManagedObject(in context: NSManagedObjectContext, withRelationships: RelationshipMO?) -> ManagedObject
}

protocol IdentifiableMO: NSManagedObject {
    var id: UUID { get set }
}
