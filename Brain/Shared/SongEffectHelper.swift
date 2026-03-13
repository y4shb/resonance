//
//  SongEffectHelper.swift
//  Resonance
//
//  Shared Core Data helpers for SongEffect creation and Song aggregate updates.
//  Used by both LearningStore (real-time) and SongImpactCalculator (batch).
//

#if os(iOS)

import Foundation
import CoreData

enum SongEffectHelper {

    // MARK: - Find or Create SongEffect

    /// Finds an existing SongEffect for the given (song, contextType) pair, or creates
    /// a new one with default scores. The lookup is keyed on (song, contextType) only --
    /// timeOfDaySlot is SET on the entity but NOT part of the lookup predicate.
    static func findOrCreateEffect(
        for song: Song,
        contextType: String,
        timeOfDaySlot: String,
        in context: NSManagedObjectContext
    ) -> SongEffect? {
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
            logError(
                "Failed to create SongEffect entity — Core Data model may be misconfigured",
                error: NSError(domain: "SongEffectHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "SongEffect entity cast failed"]),
                category: .persistence
            )
            return nil
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

    // MARK: - Update Song Aggregates

    /// Recomputes the song's aggregate scores as a confidence-weighted average
    /// across all of its SongEffect entities.
    static func updateSongAggregates(_ song: Song, in context: NSManagedObjectContext) {
        guard let effectsSet = song.effects,
              let effects = effectsSet.allObjects as? [SongEffect],
              !effects.isEmpty else {
            logDebug(
                "No effects found for song '\(song.appleMusicId ?? "unknown")', skipping aggregate update",
                category: .background
            )
            return
        }

        var totalWeight: Double = 0.0
        var weightedCalm: Double = 0.0
        var weightedFocus: Double = 0.0
        var weightedActivation: Double = 0.0
        var weightedMoodLift: Double = 0.0
        var maxConfidence: Double = 0.0

        for effect in effects {
            let weight = effect.confidenceLevel
            guard weight > 0.0 else { continue }

            totalWeight += weight
            weightedCalm += effect.calmScore * weight
            weightedFocus += effect.focusScore * weight
            weightedActivation += effect.energyScore * weight
            weightedMoodLift += effect.moodLiftScore * weight

            if effect.confidenceLevel > maxConfidence {
                maxConfidence = effect.confidenceLevel
            }
        }

        if totalWeight > 0.0 {
            song.calmScore = weightedCalm / totalWeight
            song.focusScore = weightedFocus / totalWeight
            song.activationScore = weightedActivation / totalWeight
            song.moodLiftScore = weightedMoodLift / totalWeight
            song.confidenceLevel = maxConfidence
        } else {
            // No confident effects — reset to neutral defaults so stale
            // scores don't persist from a previous state.
            song.calmScore = 0.5
            song.focusScore = 0.5
            song.activationScore = 0.5
            song.moodLiftScore = 0.5
            song.confidenceLevel = 0.0
        }
    }

    // MARK: - Update Familiarity

    /// Updates the song's familiarity score based on total play count.
    /// Formula: min(1.0, totalPlayCount / 10.0)
    static func updateFamiliarity(_ song: Song) {
        song.familiarityScore = min(1.0, Double(song.totalPlayCount) / 10.0)
    }
}

#endif
