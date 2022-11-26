//
//  DatabaseClient.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import CoreData
import ComposableArchitecture
import Combine

extension DependencyValues {
    var databaseClient: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}

struct DatabaseClient {
    let prepareDatabase: () -> Effect<Result<Void, AppError>, Never>
    let dropDatabase: () -> Effect<Result<Void, AppError>, Never>
    private let saveContext: () -> Void
    private let materializedObjects: (NSManagedObjectContext, NSPredicate) -> [NSManagedObject]
    
    private static let queue = DispatchQueue(label: "moe.mkpwnz.Hanami.DatabaseClient", qos: .utility)
}

extension DatabaseClient: DependencyKey {
    static let liveValue = DatabaseClient(
        prepareDatabase: {
            Future { promise in
                PersistenceController.shared.prepare(completion: promise)
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .catchToEffect()
        }, dropDatabase: {
            Future { promise in
                PersistenceController.shared.rebuild(completion: promise)
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .catchToEffect()
        }, saveContext: {
            let context = PersistenceController.shared.container.viewContext
            DatabaseClient.queue.sync {
                guard context.hasChanges else { return }
                do {
                    try context.save()
                } catch {
                    fatalError("Unresolved error \(error)")
                }
            }
        }, materializedObjects: { context, predicate in
            var objects: [NSManagedObject] = []
            for object in context.registeredObjects where !object.isFault {
                guard object.entity.attributesByName.keys.contains("id"),
                      predicate.evaluate(with: object)
                else { continue }
                objects.append(object)
            }
            return objects
        }
    )
}

extension DatabaseClient {
    private func batchFetch<MO: NSManagedObject>(
        entityType: MO.Type,
        fetchLimit: Int = 0,
        predicate: NSPredicate? = nil,
        findBeforeFetch: Bool = true,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) -> [MO] {
        var results: [MO] = []
        let context = PersistenceController.shared.container.viewContext
        DatabaseClient.queue.sync {
            if findBeforeFetch, let predicate {
                if let objects = materializedObjects(context, predicate) as? [MO], !objects.isEmpty {
                    results = objects
                    return
                }
            }
            let request = NSFetchRequest<MO>(
                entityName: String(describing: entityType)
            )
            request.predicate = predicate
            request.fetchLimit = fetchLimit
            request.sortDescriptors = sortDescriptors
            results = (try? context.fetch(request)) ?? []
        }
        return results
    }
    
    private func fetch<MO: NSManagedObject>(
        entityType: MO.Type,
        predicate: NSPredicate? = nil,
        findBeforeFetch: Bool = true,
        commitChanges: ((MO?) -> Void)? = nil
    ) -> MO? {
        let managedObject = batchFetch(
            entityType: entityType,
            fetchLimit: 1,
            predicate: predicate,
            findBeforeFetch: findBeforeFetch
        ).first
        commitChanges?(managedObject)
        return managedObject
    }
    
    private func fetchOrCreate<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil, commitChanges: ((MO?) -> Void)? = nil
    ) -> MO {
        if let storedMO = fetch(
            entityType: entityType, predicate: predicate, commitChanges: commitChanges
        ) {
            return storedMO
        } else {
            let newMO = MO(context: PersistenceController.shared.container.viewContext)
            commitChanges?(newMO)
            saveContext()
            return newMO
        }
    }
    
    private func batchUpdate<MO: NSManagedObject>(
        entityType: MO.Type, predicate: NSPredicate? = nil, commitChanges: ([MO]) -> Void
    ) {
        commitChanges(
            batchFetch(
                entityType: entityType,
                predicate: predicate,
                findBeforeFetch: false
            )
        )
        
        saveContext()
    }
    private func update<MO: NSManagedObject>(
        entityType: MO.Type,
        predicate: NSPredicate? = nil,
        createIfNil: Bool = false,
        commitChanges: (MO) -> Void
    ) {
        DatabaseClient.queue.sync {
            let storedMO: MO?
            if createIfNil {
                storedMO = fetchOrCreate(entityType: entityType, predicate: predicate)
            } else {
                storedMO = fetch(entityType: entityType, predicate: predicate)
            }
            if let storedMO {
                commitChanges(storedMO)
                saveContext()
            }
        }
    }
}

extension DatabaseClient {
    private func fetch<MO: IdentifiableMO>(
        entityType: MO.Type, id: UUID, findBeforeFetch: Bool = true, commitChanges: ((MO?) -> Void)? = nil
    ) -> MO? {
        fetch(
            entityType: entityType,
            predicate: NSPredicate(format: "id == %@", id.uuidString.lowercased()),
            findBeforeFetch: findBeforeFetch,
            commitChanges: commitChanges
        )
    }
    
    private func fetchOrCreate<MO: IdentifiableMO>(entityType: MO.Type, id: UUID) -> MO {
        fetchOrCreate(
            entityType: entityType,
            predicate: NSPredicate(format: "id == %@", id.uuidString.lowercased()),
            commitChanges: { $0?.id = id }
        )
    }
    
    private func update<MO: IdentifiableMO>(
        entityType: MO.Type,
        id: UUID,
        createIfNil: Bool = false,
        commitChanges: @escaping (MO) -> Void
    ) {
        DatabaseClient.queue.sync {
            let storedMO: MO?
            if createIfNil {
                storedMO = fetchOrCreate(entityType: entityType, id: id)
            } else {
                storedMO = fetch(entityType: entityType, id: id)
            }
            if let storedMO {
                commitChanges(storedMO)
                saveContext()
            }
        }
    }
    
    private func remove<MO: IdentifiableMO>(entityType: MO.Type, id: UUID) {
        let storedMO = fetch(entityType: entityType, id: id)
        
        if let storedMO {
            PersistenceController.shared.container.viewContext.delete(storedMO)
        }
    }
}

extension DatabaseClient {
    /// Retrieve all saved in DB manga
    ///
    /// - Returns: `Effect<[Manga], Never>` - Effect with either array of saved on device manga or nothing
    func retrieveAllCachedMangas() -> Effect<[Manga], Never> {
        Future { promise in
            promise(.success(batchFetch(entityType: MangaMO.self).map { $0.toEntity() }))
        }
        .eraseToEffect()
    }
    
    /// Delete manga with given ID from DB synchronically
    ///
    /// - Parameter mangaID: Manga's id, to be deleted from DB
    private func _deleteManga(mangaID: UUID) {
        remove(entityType: MangaMO.self, id: mangaID)
        
        saveContext()
    }
    
    /// Delete manga with given ID from DB
    ///
    /// - Parameter mangaID: Manga's id, to be deleted from DB
    /// - Returns: `Effect<Never, Never>` - returns nothing
    func deleteManga(mangaID: UUID) -> Effect<Never, Never> {
        .fireAndForget {
            _deleteManga(mangaID: mangaID)
        }
    }
    
    /// Delete all mangas from DB
    ///
    /// - Returns: `Effect<Never, Never>` - returns nothing
    func deleteAllMangas() -> Effect<Never, Never> {
        .fireAndForget {
            let mangas = batchFetch(entityType: MangaMO.self)
            
            for manga in mangas {
                _deleteManga(mangaID: manga.id)
            }
        }
    }
}

extension DatabaseClient {
    /// Save `ChapterDetails` in DB
    ///
    /// - Parameter chapterDetails: `ChapterDetails` to be saved in DB
    /// - Parameter pagesCount: count of pages in chapter
    /// - Parameter parentManga: Manga, whom belongs chapter
    /// - Returns: `Effect<Never, Never>` - returns nothing
    func saveChapterDetails(_ chapterDetails: ChapterDetails, pagesCount: Int, parentManga manga: Manga) -> Effect<Never, Never> {
        .fireAndForget {
            guard fetch(entityType: ChapterDetailsMO.self, id: chapterDetails.id) == nil else {
                return
            }
            
            var mangaMO = fetch(entityType: MangaMO.self, id: manga.id)
            
            if mangaMO == nil {
                mangaMO = manga.toManagedObject(in: PersistenceController.shared.container.viewContext)
            }
            
            let chapterDetailsMO = chapterDetails.toManagedObject(
                in: PersistenceController.shared.container.viewContext, withRelationships: mangaMO
            )
            
            chapterDetailsMO.pagesCount = pagesCount
            
            saveContext()
        }
    }
    
    /// Retrieve all chapters from manga with given ID from DB
    ///
    /// - Parameter mangaID: manga's ID, whose chapter need to be retrieved
    /// - Parameter scanlationGroupID: ID of scanlation group - need this if we need to fetch only chapters from specific Scanlation Group
    /// - Returns: `Effect` either with array of `CachedChapterEntry` or `AppError.notFound`
    func retrieveAllChaptersForManga(mangaID: UUID, scanlationGroupID: UUID? = nil) -> Effect<[CachedChapterEntry], AppError> {
        Future { promise in
            guard let manga = fetch(entityType: MangaMO.self, id: mangaID) else {
                promise(.failure(.notFound))
                return
            }
            
            if let scanlationGroupID {
                let filtered = manga.chapterDetailsList.filter { $0.chapter.scanlationGroupID == scanlationGroupID }
                return promise(.success(filtered))
            }
            
            return promise(.success(manga.chapterDetailsList))
        }
        .eraseToEffect()
    }
    
    /// Retrieve chapter with given ID from DB
    ///
    /// - Parameter chapterID: chapter's `UUID` to be found in DB
    /// - Returns: `CachedChapterEntry?` - nil if nothing was found or struct with `ChapterDetails` and number of pages in this chapter
    func retrieveChapter(chapterID: UUID) -> CachedChapterEntry? {
        guard let chapterMO = fetch(entityType: ChapterDetailsMO.self, id: chapterID) else {
            return nil
        }
        
        return CachedChapterEntry(chapter: chapterMO.toEntity(), pagesCount: chapterMO.pagesCount)
    }
    
    /// Delete chapter with given ID from DB
    ///
    /// - Parameter chapterID: chapter's `UUID` to be delete
    /// - Returns: `Effect<Never, Never>` - returns nothing, basically...
    func deleteChapter(chapterID: UUID) -> Effect<Never, Never> {
        .fireAndForget {
            guard let chapterMO = fetch(entityType: ChapterDetailsMO.self, id: chapterID) else {
                return
            }
            
            let parentMangaID = chapterMO.parentManga.id
            let leftChaptersCount = chapterMO.parentManga.chapterDetailsSet.count - 1
            
            remove(entityType: ChapterDetailsMO.self, id: chapterID)
            
            saveContext()
            
            if leftChaptersCount == 0 {
                _deleteManga(mangaID: parentMangaID)
            }
        }
    }
}
