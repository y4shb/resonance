//
//  SongImpactCalculator.swift
//  Resonance
//
//  Calculates per-song, per-context effectiveness scores from PlaybackEvent data.
//  Creates and updates SongEffect entities using exponential moving average.
//

#if os(iOS)

import Foundation
import CoreData

final class SongImpactCalculator {

    // MARK: - Properties

    private let persistence: PersistenceController

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Main Entry Points

    /// Calculates impacts for all unprocessed PlaybackEvents that have been grouped into sessions.
    /// Returns the number of events processed.
    @discardableResult
    func calculateImpacts() async throws -> Int {
        try await calculateImpacts(since: nil)
    }

    /// Calculates impacts for PlaybackEvents that have been grouped into sessions,
    /// optionally limited to events after `since`.
    /// Returns the number of events processed.
    @discardableResult
    func calculateImpacts(since: Date?) async throws -> Int {
        logInfo("Starting song impact calculation (since: \(since?.description ?? "all time"))", category: .background)

        let context = persistence.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Fetch events that have a session (already grouped by SessionReconstructor)
        let events = try await fetchProcessableEvents(since: since, in: context)

        guard !events.isEmpty else {
            logInfo("No processable PlaybackEvents found, skipping impact calculation", category: .background)
            return 0
        }

        logInfo("Found \(events.count) PlaybackEvents to process for song impacts", category: .background)

        var totalProcessed = 0
        let batchSize = BackfillConstants.eventBatchSize

        // Process in batches
        for batchStart in stride(from: 0, to: events.count, by: batchSize) {
            // Support cooperative cancellation between batches
            try Task.checkCancellation()

            let batchEnd = min(batchStart + batchSize, events.count)
            let batch = Array(events[batchStart..<batchEnd])

            await context.perform {
                for event in batch {
                    self.processEvent(event, in: context)
                }
            }

            // Save after each batch
            try saveContext(context)
            totalProcessed += batch.count

            logDebug(
                "Processed batch of \(batch.count) events (total: \(totalProcessed)/\(events.count))",
                category: .background
            )
        }

        logInfo("Song impact calculation complete: processed \(totalProcessed) events", category: .background)
        return totalProcessed
    }

    // MARK: - Fetch Processable Events

    /// Fetches PlaybackEvents that have an associated session (meaning they have been
    /// grouped by SessionReconstructor) and are ready for impact processing.
    private func fetchProcessableEvents(since: Date?, in context: NSManagedObjectContext) async throws -> [PlaybackEvent] {
        try await context.perform {
            let request = NSFetchRequest<PlaybackEvent>(entityName: "PlaybackEvent")

            var predicates: [NSPredicate] = [
                NSPredicate(format: "session != nil")
            ]

            if let since = since {
                predicates.append(NSPredicate(format: "startedAt >= %@", since as NSDate))
            }

            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]

            return try context.fetch(request)
        }
    }

    // MARK: - Process Single Event

    /// Processes a single PlaybackEvent: computes its ImpactScore, finds or creates
    /// the matching SongEffect, updates effect scores via EMA, and refreshes
    /// the song's aggregate scores and familiarity.
    private func processEvent(_ event: PlaybackEvent, in context: NSManagedObjectContext) {
        guard let song = event.song else {
            logError("PlaybackEvent missing song relationship, skipping", category: .background)
            return
        }

        guard let session = event.session else {
            logError("PlaybackEvent missing session relationship, skipping", category: .background)
            return
        }

        // Compute impact score from the event's biometric and behavioral data
        let impact = ImpactScore.calculate(from: event)

        // Read context from the associated session
        let contextType = session.contextType ?? "any"
        let timeOfDaySlot = session.timeOfDaySlot ?? "any"

        // Find or create the SongEffect for this (song, contextType) pair
        let effect = findOrCreateEffect(for: song, contextType: contextType, timeOfDaySlot: timeOfDaySlot, in: context)

        // Update the effect scores using EMA
        updateEffect(effect, with: impact)

        // Recompute song-level aggregate scores across all effects
        updateSongAggregates(song, in: context)

        // Update familiarity based on total play count
        updateFamiliarity(song)
    }

    // MARK: - Find or Create SongEffect

    /// Finds an existing SongEffect for the given (song, contextType) pair, or creates
    /// a new one with default scores. The lookup is keyed on (song, contextType) only --
    /// timeOfDaySlot is SET on the entity but NOT part of the lookup predicate.
    private func findOrCreateEffect(
        for song: Song,
        contextType: String,
        timeOfDaySlot: String,
        in context: NSManagedObjectContext
    ) -> SongEffect {
        let request = NSFetchRequest<SongEffect>(entityName: "SongEffect")
        request.predicate = NSPredicate(format: "song == %@ AND contextType == %@", song, contextType)
        request.fetchLimit = 1

        if let existing = (try? context.fetch(request))?.first {
            // Update the timeOfDaySlot to the most recent value
            existing.timeOfDaySlot = timeOfDaySlot
            return existing
        }

        // Create a new SongEffect with defaults
        guard let effect = NSEntityDescription.insertNewObject(forEntityName: "SongEffect", into: context) as? SongEffect else {
            logError("Failed to create SongEffect entity", category: .background)
            // This should never happen; fall through to a fetch to avoid a crash
            fatalError("Failed to create SongEffect entity")
        }

        effect.id = UUID()
        effect.song = song
        effect.contextType = contextType
        effect.timeOfDaySlot = timeOfDaySlot
        effect.calmScore = 0.5
        effect.focusScore = 0.5
        effect.energyScore = 0.5
        effect.moodLiftScore = 0.5
        effect.sampleCount = 0
        effect.confidenceLevel = 0.0
        effect.firstRecordedAt = Date()
        effect.lastUpdatedAt = Date()

        logDebug(
            "Created new SongEffect for context '\(contextType)' on song '\(song.appleMusicId ?? "unknown")'",
            category: .background
        )

        return effect
    }

    // MARK: - Update Effect with EMA

    /// Updates the SongEffect's scores using exponential moving average.
    /// Uses a two-tier learning rate: higher alpha during cold start (first N plays),
    /// then steady-state alpha for subsequent updates.
    private func updateEffect(_ effect: SongEffect, with impact: ImpactScore) {
        // Two-tier learning rate
        let alpha: Double
        if effect.sampleCount < Int64(BackfillConstants.coldStartThreshold) {
            alpha = BackfillConstants.coldStartLearningRate  // 0.4
        } else {
            alpha = LearningConstants.defaultLearningRate    // 0.2
        }

        // EMA update for each score dimension
        effect.calmScore = (1.0 - alpha) * effect.calmScore + alpha * impact.calm
        effect.energyScore = (1.0 - alpha) * effect.energyScore + alpha * impact.energy
        effect.focusScore = (1.0 - alpha) * effect.focusScore + alpha * impact.focus
        effect.moodLiftScore = (1.0 - alpha) * effect.moodLiftScore + alpha * impact.moodLift

        // Increment sample count
        effect.sampleCount += 1

        // Update confidence level
        let maxConfidence = impact.hasBiometricData ? 1.0 : BackfillConstants.behaviorOnlyMaxConfidence  // 0.7
        let fullConfidenceSamples = DecisionEngineConstants.fullConfidenceSampleCount  // 20
        effect.confidenceLevel = min(maxConfidence, Double(effect.sampleCount) / Double(fullConfidenceSamples))

        // Update timestamp
        effect.lastUpdatedAt = Date()
    }

    // MARK: - Update Song Aggregates

    /// Recomputes the song's aggregate scores as a confidence-weighted average
    /// across all of its SongEffect entities.
    private func updateSongAggregates(_ song: Song, in context: NSManagedObjectContext) {
        guard let effectsSet = song.effects,
              let effects = effectsSet.allObjects as? [SongEffect],
              !effects.isEmpty else {
            logDebug("No effects found for song '\(song.appleMusicId ?? "unknown")', skipping aggregate update", category: .background)
            return
        }

        var totalWeight: Double = 0.0
        var weightedCalm: Double = 0.0
        var weightedFocus: Double = 0.0
        var weightedActivation: Double = 0.0
        var maxConfidence: Double = 0.0

        for effect in effects {
            let weight = effect.confidenceLevel
            guard weight > 0.0 else { continue }

            totalWeight += weight
            weightedCalm += effect.calmScore * weight
            weightedFocus += effect.focusScore * weight
            weightedActivation += effect.energyScore * weight

            if effect.confidenceLevel > maxConfidence {
                maxConfidence = effect.confidenceLevel
            }
        }

        if totalWeight > 0.0 {
            song.calmScore = weightedCalm / totalWeight
            song.focusScore = weightedFocus / totalWeight
            song.activationScore = weightedActivation / totalWeight
            song.confidenceLevel = maxConfidence
        }
    }

    // MARK: - Update Familiarity

    /// Updates the song's familiarity score based on total play count.
    /// Formula: min(1.0, totalPlayCount / 10.0)
    /// Skip rate is NOT included here -- it is already penalized via effect scores.
    private func updateFamiliarity(_ song: Song) {
        song.familiarityScore = min(1.0, Double(song.totalPlayCount) / 10.0)
    }

    // MARK: - Helpers

    /// Saves the managed object context, throwing on failure.
    private func saveContext(_ context: NSManagedObjectContext) throws {
        try context.performAndWait {
            guard context.hasChanges else { return }
            try context.save()
        }
    }
}

#endif
