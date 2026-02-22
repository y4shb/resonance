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
/// Formula (from plan.md §5.3.3):
///   qualityScore = (skipScore * 0.25) + (hrvScore * 0.30) + (engagementScore * 0.25) + (sleepScore * 0.20)
struct SessionQualityScorer {

    // MARK: - Score Weights

    /// Weight for skip rate component
    static let skipWeight: Double = 0.25
    /// Weight for HRV response component
    static let hrvWeight: Double = 0.30
    /// Weight for engagement (listen percentage) component
    static let engagementWeight: Double = 0.25
    /// Weight for sleep correlation component
    static let sleepWeight: Double = 0.20

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
    /// - Returns: ScoreBreakdown with detailed scoring
    static func score(
        skipRate: Double,
        deltaHRV: Double,
        avgListenPercentage: Double,
        sleepScore: Double? = nil,
        songCount: Int = 0
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

        // Weighted sum
        let overall = (skipComponent * skipWeight) +
                       (hrvComponent * hrvWeight) +
                       (engagementComponent * engagementWeight) +
                       (sleepComponent * sleepWeight)

        return ScoreBreakdown(
            overallScore: clamp(overall, 0.0, 1.0),
            skipScore: skipComponent,
            hrvScore: hrvComponent,
            engagementScore: engagementComponent,
            sleepScore: sleepComponent,
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

        /// Get the current quality score for this running session.
        var currentScore: ScoreBreakdown {
            SessionQualityScorer.score(
                skipRate: skipRate,
                deltaHRV: deltaHRV,
                avgListenPercentage: avgListenPercentage,
                songCount: totalSongs
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
        }
    }

    // MARK: - Helpers

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}

#endif
