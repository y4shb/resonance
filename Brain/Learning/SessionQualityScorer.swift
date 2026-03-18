//
//  SessionQualityScorer.swift
//  Resonance
//
//  Extracts the session scoring formula from SessionReconstructor into a
//  reusable component. Can score both completed HistoricalSession entities
//  and in-progress sessions from raw metrics.
//

#if os(iOS)

import Foundation
import CoreData

/// Scores listening session quality using a weighted formula.
/// Can score both Core Data `HistoricalSession` entities and raw metric inputs.
///
/// Formula (updated for Workstream 2.5 arc adherence):
///   qualityScore = (skipScore * 0.20) + (hrvScore * 0.25) + (engagementScore * 0.20)
///                + (sleepScore * 0.15) + (arcAdherence * 0.20)
struct SessionQualityScorer {

    // MARK: - Score Weights

    /// Weight for skip rate component
    static let skipWeight: Double = 0.20
    /// Weight for HRV response component
    static let hrvWeight: Double = 0.25
    /// Weight for engagement (listen percentage) component
    static let engagementWeight: Double = 0.20
    /// Weight for sleep correlation component
    static let sleepWeight: Double = 0.15
    /// Weight for arc adherence component (Workstream 2.5)
    static let arcWeight: Double = 0.20

    // MARK: - Result

    /// Detailed breakdown of a session quality score.
    struct ScoreBreakdown {
        /// Overall quality score (0.0 - 1.0)
        let overallScore: Double
        /// Individual component scores (all 0.0 - 1.0)
        let skipScore: Double
        let hrvScore: Double
        let engagementScore: Double
        let sleepScore: Double
        /// Arc adherence score (0.0 - 1.0). Workstream 2.5.
        let arcAdherenceScore: Double
        /// Number of songs in the session
        let songCount: Int
        /// Whether sleep data was available
        let hasSleepData: Bool
    }

    // MARK: - Score from raw metrics

    /// Score a session from raw metrics (for real-time scoring during active sessions).
    /// - Parameters:
    ///   - skipRate: Fraction of songs skipped (0.0 - 1.0)
    ///   - deltaHRV: Change in HRV over the session (positive = relaxation)
    ///   - avgListenPercentage: Average listen percentage across songs (0.0 - 1.0)
    ///   - sleepScore: Next-night sleep quality score (nil if unavailable, 0.0 - 1.0)
    ///   - songCount: Number of songs in the session
    ///   - arcAdherence: How well songs adhered to the planned energy arc (0.0 - 1.0). Defaults to 0.5 (neutral).
    /// - Returns: ScoreBreakdown with detailed scoring
    static func score(
        skipRate: Double,
        deltaHRV: Double,
        avgListenPercentage: Double,
        sleepScore: Double? = nil,
        songCount: Int = 0,
        arcAdherence: Double = 0.5
    ) -> ScoreBreakdown {
        // 1. Skip score: lower skip rate = better
        let skipComponent = clamp(1.0 - skipRate, 0.0, 1.0)

        // 2. HRV score: positive deltaHRV = relaxation response = good
        // 20ms change is considered very significant
        let hrvComponent = clamp(0.5 + (deltaHRV / 20.0), 0.0, 1.0)

        // 3. Engagement: higher listen percentage = better
        let engagementComponent = clamp(avgListenPercentage, 0.0, 1.0)

        // 4. Sleep: use provided score or default to neutral (0.5)
        let hasSleepData = sleepScore != nil
        let sleepComponent = sleepScore ?? 0.5

        // 5. Arc adherence (Workstream 2.5)
        let arcComponent = clamp(arcAdherence, 0.0, 1.0)

        // Weighted sum
        let overall = (skipComponent * skipWeight) +
                       (hrvComponent * hrvWeight) +
                       (engagementComponent * engagementWeight) +
                       (sleepComponent * sleepWeight) +
                       (arcComponent * arcWeight)

        return ScoreBreakdown(
            overallScore: clamp(overall, 0.0, 1.0),
            skipScore: skipComponent,
            hrvScore: hrvComponent,
            engagementScore: engagementComponent,
            sleepScore: sleepComponent,
            arcAdherenceScore: arcComponent,
            songCount: songCount,
            hasSleepData: hasSleepData
        )
    }

    // MARK: - Score from HistoricalSession entity

    /// Score a completed HistoricalSession from Core Data.
    /// - Parameter session: The HistoricalSession entity to score
    /// - Returns: ScoreBreakdown with detailed scoring
    static func score(session: NSManagedObject) -> ScoreBreakdown {
        let skipRate = (session.value(forKey: "skipRate") as? Double) ?? 0.0
        let deltaHRV = (session.value(forKey: "deltaHRV") as? Double) ?? 0.0
        let avgListen = (session.value(forKey: "avgListenPercentage") as? Double) ?? 0.0
        let sleepScoreNumber = session.value(forKey: "nextNightSleepScore") as? NSNumber
        let songCount = (session.value(forKey: "totalSongsPlayed") as? Int) ?? 0

        return score(
            skipRate: skipRate,
            deltaHRV: deltaHRV,
            avgListenPercentage: avgListen,
            sleepScore: sleepScoreNumber?.doubleValue,
            songCount: songCount
        )
    }

    // MARK: - Running session metrics

    /// Tracks metrics for an in-progress session that hasn't been persisted yet.
    /// Used by LearningStore to provide real-time session quality feedback.
    final class RunningSession {
        private(set) var totalSongs: Int = 0
        private(set) var totalSkips: Int = 0
        private(set) var totalListenPercentage: Double = 0.0
        private(set) var startingHRV: Double?
        private(set) var latestHRV: Double?
        private(set) var startTime: Date = Date()

        // MARK: - Arc Tracking (Workstream 2.5)

        /// Planned energy arc for the session (per-song target energy levels).
        /// Set by the session intent system or auto-generated from music need.
        private(set) var plannedArc: [Double] = []

        /// Actual energy levels observed for each song played.
        private(set) var actualEnergies: [Double] = []

        var skipRate: Double {
            guard totalSongs > 0 else { return 0.0 }
            return Double(totalSkips) / Double(totalSongs)
        }

        var avgListenPercentage: Double {
            guard totalSongs > 0 else { return 0.0 }
            return totalListenPercentage / Double(totalSongs)
        }

        var deltaHRV: Double {
            guard let start = startingHRV, let latest = latestHRV else { return 0.0 }
            return latest - start
        }

        /// Computes the arc adherence score (0.0 - 1.0).
        /// Compares actual per-song energy levels against the planned arc.
        /// Songs that stay on-curve are rewarded; deviations are penalized.
        var arcAdherence: Double {
            guard !plannedArc.isEmpty, !actualEnergies.isEmpty else { return 0.5 }

            let compareCount = min(plannedArc.count, actualEnergies.count)
            guard compareCount > 0 else { return 0.5 }

            var totalDeviation = 0.0
            for i in 0..<compareCount {
                let deviation = abs(actualEnergies[i] - plannedArc[i])
                totalDeviation += deviation
            }

            let avgDeviation = totalDeviation / Double(compareCount)
            // Map average deviation to a score:
            // 0.0 deviation = 1.0 score (perfect adherence)
            // 0.5 deviation = 0.0 score (completely off-arc)
            return clamp(1.0 - avgDeviation * 2.0, 0.0, 1.0)
        }

        /// Record a completed song in this session.
        func recordSong(wasSkipped: Bool, listenPercentage: Double, currentHRV: Double?) {
            totalSongs += 1
            if wasSkipped { totalSkips += 1 }
            totalListenPercentage += listenPercentage

            if let hrv = currentHRV {
                if startingHRV == nil { startingHRV = hrv }
                latestHRV = hrv
            }
        }

        /// Records the actual energy level of a song that was just played.
        /// Used by arc adherence scoring (Workstream 2.5).
        func recordSongEnergy(_ energy: Double) {
            actualEnergies.append(clamp(energy, 0.0, 1.0))
        }

        /// Sets the planned energy arc for this session.
        /// Called when a session intent is set or when the DecisionEngine
        /// pre-computes the next N songs.
        func setPlannedArc(_ arc: [Double]) {
            plannedArc = arc.map { clamp($0, 0.0, 1.0) }
        }

        /// Sets the planned arc from a SessionArc (WS-4).
        /// Extracts the energy trajectory and sets it as the planned arc.
        func setSessionArc(_ sessionArc: SessionArc) {
            plannedArc = sessionArc.energyTrajectory.map { $0.energy }
        }

        /// Evaluates arc adherence using the SessionCritic (WS-4).
        /// Returns a detailed ArcAdherenceResult instead of a simple score.
        /// The `overallScore` of the result is used as R_session.
        func evaluateArcAdherence(sessionArc: SessionArc) -> ArcAdherenceResult {
            let critic = SessionCritic()
            let observations = actualEnergies.enumerated().map { index, energy in
                SongObservation(
                    songIndex: index,
                    actualBPM: 0, // BPM not tracked in RunningSession
                    actualEnergy: energy,
                    wasSkipped: false,
                    listenPercentage: totalSongs > 0
                        ? totalListenPercentage / Double(totalSongs)
                        : 1.0
                )
            }
            return critic.evaluate(arc: sessionArc, observations: observations)
        }

        /// Computes the arc adherence for a single song at a given position.
        /// Returns how well the song's energy matches the planned arc target.
        /// - Parameters:
        ///   - songEnergy: The song's energy level (0.0 - 1.0).
        ///   - position: The song's index in the session (0-based).
        /// - Returns: Adherence score (0.0 - 1.0) for this song.
        func songArcAdherence(songEnergy: Double, position: Int) -> Double {
            guard position < plannedArc.count else { return 0.5 }
            let target = plannedArc[position]
            let deviation = abs(songEnergy - target)
            return clamp(1.0 - deviation * 2.0, 0.0, 1.0)
        }

        /// Get the current quality score for this running session.
        var currentScore: ScoreBreakdown {
            SessionQualityScorer.score(
                skipRate: skipRate,
                deltaHRV: deltaHRV,
                avgListenPercentage: avgListenPercentage,
                songCount: totalSongs,
                arcAdherence: arcAdherence
            )
        }

        /// Reset for a new session.
        func reset() {
            totalSongs = 0
            totalSkips = 0
            totalListenPercentage = 0.0
            startingHRV = nil
            latestHRV = nil
            startTime = Date()
            plannedArc = []
            actualEnergies = []
        }
    }

    // MARK: - Helpers

    static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}

#endif
