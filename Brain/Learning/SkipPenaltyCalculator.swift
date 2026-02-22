//
//  SkipPenaltyCalculator.swift
//  Resonance
//
//  Calculates time-weighted skip penalties for the real-time learning loop.
//  Early skips (< 15% listened) are penalized more severely than late skips.
//

#if os(iOS)

import Foundation

/// Calculates time-weighted skip penalties for the real-time learning loop.
/// Early skips (< 15% listened) are penalized more severely than late skips.
struct SkipPenaltyCalculator {

    /// Result of a skip penalty calculation.
    struct PenaltyResult {
        /// The penalty value (negative, applied to effect scores). Range: [-0.3, 0.0]
        let penalty: Double
        /// Whether the event counts as a skip
        let isSkip: Bool
        /// Classification of the skip timing
        let skipTiming: SkipTiming
        /// Weight factor from user preferences
        let userWeight: Double
        /// Final weighted penalty (penalty * userWeight)
        var weightedPenalty: Double { penalty * userWeight }
    }

    enum SkipTiming: String {
        case noSkip = "no_skip"
        case earlySkip = "early_skip"    // < 15% listened
        case lateSkip = "late_skip"      // 15-30% listened
        case nearComplete = "near_complete" // > 30% but still marked skip
    }

    /// Calculate skip penalty for a playback event.
    /// - Parameters:
    ///   - wasSkipped: Whether the user manually skipped
    ///   - listenPercentage: How much of the song was listened to (0.0 - 1.0)
    ///   - preferences: User preferences for penalty weight
    /// - Returns: PenaltyResult with the calculated penalty
    static func calculate(
        wasSkipped: Bool,
        listenPercentage: Double,
        preferences: UserPreferences = .load()
    ) -> PenaltyResult {
        // Determine if this is actually a skip
        // A song is considered skipped if:
        // 1. User manually skipped, OR
        // 2. Listen percentage < minimum threshold (LearningConstants.minimumListenPercentage = 0.3)
        let isSkip = wasSkipped || listenPercentage < LearningConstants.minimumListenPercentage

        guard isSkip else {
            return PenaltyResult(
                penalty: 0.0,
                isSkip: false,
                skipTiming: .noSkip,
                userWeight: preferences.skipPenaltyWeight
            )
        }

        // Two-tier skip penalty (matching ImpactScore.swift pattern)
        let penalty: Double
        let timing: SkipTiming

        if listenPercentage < BackfillConstants.earlySkipThreshold {
            // Early skip (< 15%): severe penalty
            penalty = -LearningConstants.skipPenaltyMultiplier  // -0.3
            timing = .earlySkip
        } else if listenPercentage < LearningConstants.minimumListenPercentage {
            // Late skip (15-30%): moderate penalty
            penalty = -BackfillConstants.lateSkipPenalty  // -0.15
            timing = .lateSkip
        } else {
            // Manual skip after 30%: mild penalty
            penalty = -BackfillConstants.lateSkipPenalty * 0.5  // -0.075
            timing = .nearComplete
        }

        return PenaltyResult(
            penalty: penalty,
            isSkip: true,
            skipTiming: timing,
            userWeight: preferences.skipPenaltyWeight
        )
    }
}

#endif
