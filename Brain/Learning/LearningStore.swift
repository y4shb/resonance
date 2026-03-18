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
        // Capture persistence reference on MainActor before entering background context.
        // This avoids accessing @MainActor-isolated `self` from the background thread.
        let persistence = self.persistence

        persistence.container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

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
                hrAtStart: event.hrAtStart,
                hrvAtStart: event.hrvAtStart,
                listenPercentage: event.listenPercentage,
                wasSkipped: event.wasSkipped,
                preferences: preferences
            )

            // 3. Compute final impact scores (clamp to [0, 1])
            let calmImpact = Self.clamp(0.5 + responseResult.weightedCalmCredit + skipResult.weightedPenalty)
            let energyImpact = Self.clamp(0.5 + responseResult.weightedEnergyCredit + skipResult.weightedPenalty)
            let focusImpact = Self.clamp(0.5 + responseResult.focusCredit + skipResult.weightedPenalty)
            let moodLiftImpact = Self.clamp(0.5 + responseResult.valenceCredit + skipResult.weightedPenalty)

            // 4. Determine context for SongEffect lookup
            // Use the session's context if available, otherwise "any"
            let contextType = event.session?.contextType ?? "any"
            let timeOfDaySlot = event.session?.timeOfDaySlot ?? "any"

            // 5. Find or create the SongEffect for this song + context
            guard let effect = SongEffectHelper.findOrCreateEffect(
                for: song,
                contextType: contextType,
                timeOfDaySlot: timeOfDaySlot,
                in: context
            ) else {
                logError("Failed to find or create SongEffect, skipping learning update", category: .persistence)
                return
            }

            // 6. Apply EMA update via shared helper (two-tier learning rate)
            LearningFormulaHelper.updateEffect(
                effect,
                calm: calmImpact,
                energy: energyImpact,
                focus: focusImpact,
                moodLift: moodLiftImpact,
                hasBiometricData: responseResult.hasBiometricData,
                userLearningRate: preferences.learningRate
            )

            let confidence = effect.confidenceLevel
            let alpha = LearningFormulaHelper.learningRate(
                sampleCount: effect.sampleCount - 1,
                userLearningRate: preferences.learningRate
            )

            // 7. Update Song aggregate scores (confidence-weighted average across all effects)
            SongEffectHelper.updateSongAggregates(song, in: context)

            // 8. Update familiarity (play/skip counts are managed by
            // SongRepository.updatePlaybackStats to avoid double-counting)
            SongEffectHelper.updateFamiliarity(song)

            // 8.5. Mark event as impact-processed so SongImpactCalculator
            // (batch backfill) won't double-count this event's EMA contribution.
            event.isImpactProcessed = true

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
            let isSkip = skipResult.isSkip
            // Compute absolute HRV for session tracking (RunningSession expects
            // absolute values, not deltas, so it can compute session-level change).
            let currentAbsoluteHRV: Double? = event.hrvAtStart > 0 ? (event.hrvAtStart + event.hrvDelta) : nil

            // Publish result and update running session on main thread
            Task { @MainActor [weak self] in
                self?.lastProcessedImpact = impact
                self?.runningSession.recordSong(
                    wasSkipped: isSkip,
                    listenPercentage: listenPercentage,
                    currentHRV: currentAbsoluteHRV
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
