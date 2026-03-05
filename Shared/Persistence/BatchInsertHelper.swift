//
//  BatchInsertHelper.swift
//  Resonance
//
//  NSBatchInsertRequest utilities for high-performance Core Data operations.
//  Bypasses managed object context for ~10x performance on large imports.
//

import CoreData

// MARK: - Batch Insert Helper

enum BatchInsertHelper {
    /// Batch-inserts biometric samples into Core Data using NSBatchInsertRequest.
    /// This bypasses the managed object context and writes directly to the SQLite store,
    /// providing ~10x performance improvement for large imports.
    ///
    /// - Parameters:
    ///   - samples: Array of (timestamp, heartRate, hrv, eventId) tuples
    ///   - container: The persistent container to use
    /// - Returns: Number of inserted records
    @discardableResult
    static func batchInsertBiometricSamples(
        _ samples: [(timestamp: Date, heartRate: Double?, hrv: Double?, eventId: UUID?)],
        into container: NSPersistentContainer
    ) throws -> Int {
        guard !samples.isEmpty else { return 0 }

        var index = 0
        let request = NSBatchInsertRequest(
            entityName: "BiometricSample",
            managedObjectHandler: { managedObject in
                guard index < samples.count else { return true }

                let sample = samples[index]
                managedObject.setValue(UUID(), forKey: "id")
                managedObject.setValue(sample.timestamp, forKey: "timestamp")
                if let hr = sample.heartRate {
                    managedObject.setValue(hr, forKey: "heartRate")
                }
                if let hrv = sample.hrv {
                    managedObject.setValue(hrv, forKey: "hrv")
                }
                if let eventId = sample.eventId {
                    managedObject.setValue(eventId, forKey: "playbackEventId")
                }

                index += 1
                return false
            }
        )

        request.resultType = .objectIDs

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        let result = try context.execute(request) as? NSBatchInsertResult

        // Merge changes into the view context so UI updates
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSInsertedObjectsKey: objectIDs],
                into: [PersistenceController.shared.viewContext]
            )
            logInfo("Batch-inserted \(objectIDs.count) biometric samples", category: .persistence)
            return objectIDs.count
        }

        return index
    }

    /// Batch-inserts playback events into Core Data for historical backfill.
    @discardableResult
    static func batchInsertPlaybackEvents(
        _ events: [(songAppleMusicId: String, startedAt: Date, endedAt: Date?, listenPercentage: Double, wasSkipped: Bool)],
        into container: NSPersistentContainer
    ) throws -> Int {
        guard !events.isEmpty else { return 0 }

        var index = 0
        let request = NSBatchInsertRequest(
            entityName: "PlaybackEvent",
            managedObjectHandler: { managedObject in
                guard index < events.count else { return true }

                let event = events[index]
                managedObject.setValue(UUID(), forKey: "id")
                managedObject.setValue(event.songAppleMusicId, forKey: "songAppleMusicId")
                managedObject.setValue(event.startedAt, forKey: "startedAt")
                managedObject.setValue(event.endedAt, forKey: "endedAt")
                managedObject.setValue(event.listenPercentage, forKey: "listenPercentage")
                managedObject.setValue(event.wasSkipped, forKey: "wasSkipped")
                managedObject.setValue(false, forKey: "isImpactProcessed")

                index += 1
                return false
            }
        )

        request.resultType = .objectIDs

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        let result = try context.execute(request) as? NSBatchInsertResult

        if let objectIDs = result?.result as? [NSManagedObjectID] {
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSInsertedObjectsKey: objectIDs],
                into: [PersistenceController.shared.viewContext]
            )
            logInfo("Batch-inserted \(objectIDs.count) playback events", category: .persistence)
            return objectIDs.count
        }

        return index
    }
}
