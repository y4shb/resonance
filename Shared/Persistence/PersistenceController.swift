//
//  PersistenceController.swift
//  AIDJ
//
//  Core Data stack management with App Group support for cross-target access
//

import CoreData
import Foundation

/// Manages the Core Data stack with support for App Groups and multiple targets
public final class PersistenceController: @unchecked Sendable {
    // MARK: - Singleton

    /// Shared instance for production use
    public static let shared = PersistenceController()

    /// Preview instance with in-memory store for SwiftUI previews
    public static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Add sample data for previews
        do {
            try controller.createSampleData(in: context)
            try context.save()
        } catch {
            logError("Failed to create preview data", error: error, category: .persistence)
        }

        return controller
    }()

    // MARK: - Properties

    /// The persistent container
    public let container: NSPersistentContainer

    /// Main view context for UI operations
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Whether the store is in-memory only
    private let inMemory: Bool

    // MARK: - Initialization

    /// Creates a new PersistenceController
    /// - Parameter inMemory: If true, uses an in-memory store (for testing/previews)
    public init(inMemory: Bool = false) {
        self.inMemory = inMemory

        // Create container with the model
        container = NSPersistentContainer(name: "AIDJ")

        // Configure store description
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use App Group container for shared access
            if let appGroupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
            ) {
                let storeURL = appGroupURL.appendingPathComponent("AIDJ.sqlite")
                let description = NSPersistentStoreDescription(url: storeURL)
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
                container.persistentStoreDescriptions = [description]

                logInfo("Using App Group store at: \(storeURL.path)", category: .persistence)
            } else {
                logWarning("App Group not available, using default store location", category: .persistence)
            }
        }

        // Load persistent stores
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                logCritical(
                    "Failed to load persistent store: \(storeDescription)",
                    error: error,
                    category: .persistence
                )
                // In production, you might want to handle this more gracefully
                // For now, we'll crash in debug to catch issues early
                #if DEBUG
                fatalError("Core Data store failed to load: \(error)")
                #endif
            } else {
                logInfo("Loaded persistent store: \(storeDescription)", category: .persistence)
            }
        }

        // Configure view context
        configureViewContext()
    }

    // MARK: - Context Configuration

    private func configureViewContext() {
        // Automatically merge changes from parent
        viewContext.automaticallyMergesChangesFromParent = true

        // Set merge policy to favor in-memory changes
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Set name for debugging
        viewContext.name = "ViewContext"

        // Enable persistent history tracking for sync
        if !inMemory {
            let description = container.persistentStoreDescriptions.first
            description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
    }

    // MARK: - Background Context

    /// Creates a new background context for batch operations
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.name = "BackgroundContext-\(UUID().uuidString.prefix(8))"
        return context
    }

    /// Performs work on a background context
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            block(context)
        }
    }

    /// Performs work on a background context with async/await
    @available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
    public func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            return try block(context)
        }
    }

    // MARK: - Save Operations

    /// Saves the view context if there are changes
    public func save() {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
            logDebug("View context saved successfully", category: .persistence)
        } catch {
            logError("Failed to save view context", error: error, category: .persistence)
        }
    }

    /// Saves a specific context if there are changes
    public func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
            logDebug("Context '\(context.name ?? "unnamed")' saved successfully", category: .persistence)
        } catch {
            logError("Failed to save context '\(context.name ?? "unnamed")'", error: error, category: .persistence)
        }
    }

    /// Saves a context asynchronously
    public func saveAsync(context: NSManagedObjectContext, completion: ((Error?) -> Void)? = nil) {
        context.perform {
            guard context.hasChanges else {
                completion?(nil)
                return
            }

            do {
                try context.save()
                logDebug("Context '\(context.name ?? "unnamed")' saved asynchronously", category: .persistence)
                completion?(nil)
            } catch {
                logError("Failed to save context asynchronously", error: error, category: .persistence)
                completion?(error)
            }
        }
    }

    // MARK: - Data Management

    /// Deletes all data from the store (use with caution!)
    public func deleteAllData() throws {
        let entityNames = container.managedObjectModel.entities.compactMap { $0.name }

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: changes,
                        into: [viewContext]
                    )
                    logInfo("Deleted \(objectIDs.count) \(entityName) objects", category: .persistence)
                }
            } catch {
                logError("Failed to delete \(entityName) data", error: error, category: .persistence)
                throw error
            }
        }
    }

    /// Returns the store URL for debugging
    public var storeURL: URL? {
        container.persistentStoreDescriptions.first?.url
    }

    /// Returns the store size in bytes
    public var storeSize: Int64? {
        guard let url = storeURL else { return nil }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }

    // MARK: - Sample Data (for previews and testing)

    private func createSampleData(in context: NSManagedObjectContext) throws {
        // Create sample playlist
        let playlist = NSEntityDescription.insertNewObject(forEntityName: "Playlist", into: context)
        playlist.setValue(UUID(), forKey: "id")
        playlist.setValue("sample_playlist_1", forKey: "appleMusicId")
        playlist.setValue("Chill Vibes", forKey: "name")
        playlist.setValue(true, forKey: "isUserCreated")
        playlist.setValue(Int64(10), forKey: "songCount")
        playlist.setValue(Date(), forKey: "createdAt")

        // Create sample songs
        let sampleSongs = [
            ("Weightless", "Marconi Union", 60.0),
            ("Clair de Lune", "Claude Debussy", 72.0),
            ("Sunset Lover", "Petit Biscuit", 100.0)
        ]

        for (title, artist, bpm) in sampleSongs {
            let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context)
            song.setValue(UUID(), forKey: "id")
            song.setValue("apple_\(title.lowercased().replacingOccurrences(of: " ", with: "_"))", forKey: "appleMusicId")
            song.setValue(title, forKey: "title")
            song.setValue(artist, forKey: "artistName")
            song.setValue(bpm, forKey: "bpm")
            song.setValue(0.3, forKey: "energyEstimate")
            song.setValue(0.8, forKey: "calmScore")
            song.setValue(240.0, forKey: "durationSeconds")
        }
    }
}

// MARK: - Fetch Request Helpers

extension PersistenceController {
    /// Fetches all objects of a given entity
    public func fetchAll<T: NSManagedObject>(_ type: T.Type) -> [T] {
        let request = T.fetchRequest()
        do {
            return try viewContext.fetch(request) as? [T] ?? []
        } catch {
            logError("Failed to fetch \(T.self)", error: error, category: .persistence)
            return []
        }
    }

    /// Fetches objects matching a predicate
    public func fetch<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        limit: Int? = nil
    ) -> [T] {
        let request = T.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            return try viewContext.fetch(request) as? [T] ?? []
        } catch {
            logError("Failed to fetch \(T.self) with predicate", error: error, category: .persistence)
            return []
        }
    }

    /// Counts objects matching a predicate
    public func count<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil) -> Int {
        let request = T.fetchRequest()
        request.predicate = predicate

        do {
            return try viewContext.count(for: request)
        } catch {
            logError("Failed to count \(T.self)", error: error, category: .persistence)
            return 0
        }
    }
}
