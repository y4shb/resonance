//
//  LearningStore.swift
//  Resonance
//
//  Real-time learning store that processes playback events as they happen.
//  Mirrors the batch logic of SongImpactCalculator but operates on individual events
//  for immediate feedback during active listening sessions.
//
//  Part of Phase 8 (Learning Loop).
//

#if os(iOS)

import Foundation
import CoreData
import Combine

/// Real-time learning store that processes playback events as they happen.
/// Mirrors the batch logic of SongImpactCalculator but operates on individual events.
@MainActor
final class LearningStore: ObservableObject {

    // MARK: - Published State

    /// The most recent impact that was processed
    @Published private(set) var lastProcessedImpact: ProcessedImpact?

    /// Running session quality tracker
    @Published private(set) var runningSession = SessionQualityScorer.RunningSession()

    // MARK: - Dependencies

    private let persistence: PersistenceController

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        logInfo("LearningStore initialized", category: .learning)
    }

    // MARK: - Process Playback Event

    /// Process a completed playback event and update song effect scores.
    /// Called by NowPlayingViewModel when a song finishes or is skipped.
    /// - Parameter eventObjectID: The NSManagedObjectID of the completed PlaybackEvent
    func processPlaybackEvent(eventObjectID: NSManagedObjectID) {
        persistence.container.performBackgroundTask { [weak self] context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            guard let self = self else { return }

            guard let event = try? context.existingObject(with: eventObjectID) as? PlaybackEvent else {
                logWarning("LearningStore: could not find PlaybackEvent for objectID \(eventObjectID)", category: .learning)
                return
            }

            guard let song = event.song else {
                logWarning("LearningStore: PlaybackEvent has no song relationship, skipping", category: .learning)
                return
            }

            let preferences = UserPreferences.load()

            // 1. Calculate skip penalty
            let skipResult = SkipPenaltyCalculator.calculate(
                wasSkipped: event.wasSkipped,
                listenPercentage: event.listenPercentage,
                preferences: preferences
            )

            // 2. Calculate biometric response credit
            let responseResult = ResponseCreditCalculator.calculate(
                hrvDelta: event.hrvDelta,
                hrDelta: event.hrDelta,
                listenPercentage: event.listenPercentage,
                wasSkipped: event.wasSkipped,
                preferences: preferences
            )

            // 3. Compute final impact scores (clamp to [0, 1])
            let calmImpact = Self.clamp(0.5 + responseResult.calmCredit + skipResult.weightedPenalty)
            let energyImpact = Self.clamp(0.5 + responseResult.energyCredit + skipResult.weightedPenalty)
            let focusImpact = Self.clamp(0.5 + responseResult.focusCredit + skipResult.weightedPenalty)
            let moodLiftImpact = Self.clamp(0.5 + responseResult.focusCredit)

            // 4. Determine context for SongEffect lookup
            // Use the session's context if available, otherwise "any"
            let contextType = event.session?.contextType ?? "any"
            let timeOfDaySlot = event.session?.timeOfDaySlot ?? "any"

            // 5. Find or create the SongEffect for this song + context
            let effect = self.findOrCreateEffect(
                for: song,
                contextType: contextType,
                timeOfDaySlot: timeOfDaySlot,
                in: context
            )

            // 6. Apply EMA update (two-tier learning rate)
            let alpha: Double
            if effect.sampleCount < Int64(BackfillConstants.coldStartThreshold) {
                alpha = BackfillConstants.coldStartLearningRate  // 0.4 for first 5 plays
            } else {
                alpha = preferences.learningRate  // User-configurable, default 0.2
            }

            effect.calmScore = (1.0 - alpha) * effect.calmScore + alpha * calmImpact
            effect.energyScore = (1.0 - alpha) * effect.energyScore + alpha * energyImpact
            effect.focusScore = (1.0 - alpha) * effect.focusScore + alpha * focusImpact
            effect.moodLiftScore = (1.0 - alpha) * effect.moodLiftScore + alpha * moodLiftImpact

            // Increment sample count
            effect.sampleCount += 1

            // Confidence: full at 20 samples, capped at 0.7 without biometrics
            let maxConfidence = responseResult.hasBiometricData ? 1.0 : BackfillConstants.behaviorOnlyMaxConfidence
            let fullConfidenceSamples = Double(DecisionEngineConstants.fullConfidenceSampleCount)
            let confidence = min(maxConfidence, Double(effect.sampleCount) / fullConfidenceSamples)
            effect.confidenceLevel = confidence
            effect.lastUpdatedAt = Date()

            // 7. Update Song aggregate scores (confidence-weighted average across all effects)
            self.updateSongAggregates(song, in: context)

            // 8. Update play/skip counts and familiarity
            song.totalPlayCount += 1
            if skipResult.isSkip {
                song.totalSkipCount += 1
            }
            self.updateFamiliarity(song)

            // 9. Save
            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                logError("LearningStore: failed to save context", error: error, category: .learning)
            }

            // 10. Build result for main-thread publishing
            let impact = ProcessedImpact(
                calmImpact: calmImpact,
                energyImpact: energyImpact,
                focusImpact: focusImpact,
                wasSkip: skipResult.isSkip,
                skipTiming: skipResult.skipTiming.rawValue,
                hasBiometrics: responseResult.hasBiometricData,
                alpha: alpha,
                newConfidence: confidence
            )

            let listenPercentage = event.listenPercentage
            let hrvDelta = event.hrvDelta
            let isSkip = skipResult.isSkip

            // Publish result and update running session on main thread
            Task { @MainActor [weak self] in
                self?.lastProcessedImpact = impact
                self?.runningSession.recordSong(
                    wasSkipped: isSkip,
                    listenPercentage: listenPercentage,
                    currentHRV: hrvDelta != 0 ? hrvDelta : nil
                )
                logInfo(
                    "LearningStore: processed event -- calm=\(String(format: "%.2f", calmImpact)), "
                    + "energy=\(String(format: "%.2f", energyImpact)), skip=\(isSkip), "
                    + "alpha=\(String(format: "%.2f", alpha)), confidence=\(String(format: "%.2f", confidence))",
                    category: .learning
                )
            }
        }
    }

    // MARK: - Session Management

    /// Reset the running session tracker (e.g., after 30min gap).
    func resetSession() {
        runningSession = SessionQualityScorer.RunningSession()
        logInfo("LearningStore: session reset", category: .learning)
    }

    // MARK: - Core Data Helpers

    /// Find existing SongEffect or create a new one. Mirrors SongImpactCalculator.findOrCreateEffect pattern.
    private nonisolated func findOrCreateEffect(
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
            logError("LearningStore: failed to create SongEffect entity", category: .learning)
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
            "LearningStore: created new SongEffect for context '\(contextType)' on song '\(song.appleMusicId ?? "unknown")'",
            category: .learning
        )

        return effect
    }

    /// Update Song aggregate scores from all its SongEffect records.
    /// Mirrors SongImpactCalculator.updateSongAggregates pattern.
    private nonisolated func updateSongAggregates(_ song: Song, in context: NSManagedObjectContext) {
        guard let effectsSet = song.effects,
              let effects = effectsSet.allObjects as? [SongEffect],
              !effects.isEmpty else {
            logDebug(
                "LearningStore: no effects found for song '\(song.appleMusicId ?? "unknown")', skipping aggregate update",
                category: .learning
            )
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

    /// Updates the song's familiarity score based on total play count.
    /// Formula: min(1.0, totalPlayCount / 10.0)
    private nonisolated func updateFamiliarity(_ song: Song) {
        song.familiarityScore = min(1.0, Double(song.totalPlayCount) / 10.0)
    }

    // MARK: - Helpers

    /// Clamp a value to [0, 1].
    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}

// MARK: - Processed Impact Result

/// Captures the result of processing a single playback event for UI feedback.
struct ProcessedImpact {
    /// Calm dimension impact score (0-1, centered at 0.5)
    let calmImpact: Double
    /// Energy dimension impact score (0-1, centered at 0.5)
    let energyImpact: Double
    /// Focus dimension impact score (0-1, centered at 0.5)
    let focusImpact: Double
    /// Whether the event was classified as a skip
    let wasSkip: Bool
    /// Skip timing classification (e.g. "early", "late", "none")
    let skipTiming: String
    /// Whether biometric data contributed to the impact calculation
    let hasBiometrics: Bool
    /// The EMA learning rate that was applied
    let alpha: Double
    /// The new confidence level for the updated SongEffect
    let newConfidence: Double
}

#endif
