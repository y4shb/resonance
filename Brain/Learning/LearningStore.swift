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

    /// Per-track resonance data accumulated during the current session.
    private(set) var trackResonanceData: [TrackResonanceData] = []

    /// Whether biometric data was available during this session.
    private(set) var sessionHadBiometrics = false

    // MARK: - Dependencies

    private let persistence: PersistenceController
    private let resonanceCalculator = ResonanceScoreCalculator()
    private let resonanceStore = ResonanceScoreStore()

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

            // 11. Capture per-track resonance data for post-session scoring
            let songTitle = song.title ?? "Unknown"
            let artistName = song.artistName ?? "Unknown"
            let songAppleMusicId = song.appleMusicId ?? ""
            let hrDelta = event.hrDelta
            let hasBio = responseResult.hasBiometricData

            // Publish result and update running session on main thread
            Task { @MainActor [weak self] in
                self?.lastProcessedImpact = impact
                self?.runningSession.recordSong(
                    wasSkipped: isSkip,
                    listenPercentage: listenPercentage,
                    currentHRV: currentAbsoluteHRV
                )

                // Record per-track resonance data (intent will be applied at scoring time)
                self?.recordTrackResonance(
                    songTitle: songTitle,
                    artistName: artistName,
                    songAppleMusicId: songAppleMusicId,
                    hrDelta: hrDelta,
                    completionRatio: listenPercentage,
                    wasSkipped: isSkip,
                    hasBiometrics: hasBio
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

    // MARK: - Per-Track Resonance Recording

    /// Records per-track biometric alignment data for resonance scoring.
    /// Called on the main actor after each playback event is processed.
    private func recordTrackResonance(
        songTitle: String,
        artistName: String,
        songAppleMusicId: String,
        hrDelta: Double,
        completionRatio: Double,
        wasSkipped: Bool,
        hasBiometrics: Bool
    ) {
        if hasBiometrics {
            sessionHadBiometrics = true
        }

        // Use a neutral alignment for now; final alignment is computed
        // at score time when we know the session intent.
        let trackData = TrackResonanceData(
            songTitle: songTitle,
            artistName: artistName,
            songAppleMusicId: songAppleMusicId,
            alignment: hasBiometrics ? 0.5 : 0.5, // Placeholder; recomputed in computeResonanceScore
            hrDirectionMatch: false,                // Placeholder; recomputed in computeResonanceScore
            completionRatio: completionRatio,
            wasSkipped: wasSkipped
        )

        // Store the raw HR delta alongside the track data for later recomputation
        pendingHRDeltas.append(hrDelta)
        trackResonanceData.append(trackData)
    }

    /// Raw HR deltas for each track, aligned by index with `trackResonanceData`.
    private var pendingHRDeltas: [Double] = []

    // MARK: - Resonance Score Computation

    /// Computes the resonance score for the current session and persists it.
    ///
    /// - Parameter sessionIntent: The session's music need, used to interpret
    ///   whether HR direction changes are aligned with the goal.
    /// - Returns: The computed `ResonanceScoreResult`, or nil if no tracks were played.
    func computeResonanceScore(sessionIntent: MusicNeed) -> ResonanceScoreResult? {
        guard !trackResonanceData.isEmpty else { return nil }

        let sessionDuration = Date().timeIntervalSince(runningSession.startTime)
        guard sessionDuration >= ResonanceScoreCalculator.minimumSessionDuration else {
            logInfo("LearningStore: session too short for resonance score (\(Int(sessionDuration))s)", category: .learning)
            return nil
        }

        // Recompute alignment per track using the session intent and stored HR deltas
        var finalTracks: [TrackResonanceData] = []
        for (index, track) in trackResonanceData.enumerated() {
            let hrDelta = index < pendingHRDeltas.count ? pendingHRDeltas[index] : 0.0
            let (alignment, hrMatch) = ResonanceScoreCalculator.computeTrackAlignment(
                hrDelta: hrDelta,
                sessionIntent: sessionIntent,
                completionRatio: track.completionRatio,
                wasSkipped: track.wasSkipped
            )

            let updatedTrack = TrackResonanceData(
                songTitle: track.songTitle,
                artistName: track.artistName,
                songAppleMusicId: track.songAppleMusicId,
                alignment: alignment,
                hrDirectionMatch: hrMatch,
                completionRatio: track.completionRatio,
                wasSkipped: track.wasSkipped
            )
            finalTracks.append(updatedTrack)
        }

        // Compute the score
        let result = resonanceCalculator.computeScore(
            tracks: finalTracks,
            sessionIntent: sessionIntent,
            sessionDuration: sessionDuration,
            biometricAvailable: sessionHadBiometrics
        )

        // Persist to history
        let historyEntry = ResonanceScoreHistoryEntry(
            id: UUID(),
            date: Date(),
            score: result.overallScore,
            biometricScore: result.biometricScore,
            engagementScore: result.engagementScore,
            tracksPlayed: result.tracksPlayed,
            sessionDuration: sessionDuration,
            sessionIntent: sessionIntent.rawValue
        )
        resonanceStore.save(historyEntry)

        logInfo(
            "LearningStore: resonance score computed -- overall=\(result.overallScore), "
            + "bio=\(result.biometricScore), engagement=\(result.engagementScore), "
            + "tracks=\(result.tracksPlayed)",
            category: .learning
        )

        return result
    }

    // MARK: - Session Management

    /// Reset the running session tracker (e.g., after 30min gap).
    func resetSession() {
        runningSession = SessionQualityScorer.RunningSession()
        trackResonanceData = []
        pendingHRDeltas = []
        sessionHadBiometrics = false
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
