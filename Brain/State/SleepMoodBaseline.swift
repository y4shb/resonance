//
//  SleepMoodBaseline.swift
//  Resonance
//
//  Computes a morning mood baseline from overnight sleep metrics.
//  Used by the StateEngine (R6) to adjust initial stress and valence
//  estimates during the morning hours (05:00-12:00).
//
//  Research citations:
//  - de Zambotti et al., MDPI Sensors 2023: overnight HRV and sleep
//    quality predict next-day mood and stress susceptibility.
//  - Kalmbach et al., Sleep Medicine Reviews 2018: sleep duration and
//    deep sleep percentage correlate with next-day positive affect.
//  - Natarajan et al., npj Digital Medicine 2021: wrist-worn respiratory
//    rate during sleep tracks autonomic recovery quality.
//

#if os(iOS)

import Foundation

// MARK: - Morning Mood Baseline

/// Encapsulates morning mood adjustments derived from overnight sleep data.
///
/// A composite score above 0.5 indicates restorative sleep (reduces morning stress,
/// improves morning valence). A score below 0.5 indicates poor sleep (elevates
/// stress, depresses valence).
///
/// Adjustments are intentionally small to complement, not override,
/// real-time biometric signals.
internal struct MorningMoodBaseline {

    // MARK: - Properties

    /// Stress adjustment to apply during morning hours.
    /// Negative values reduce stress (good sleep), positive values increase it.
    /// Range: approximately -0.1 to +0.1.
    internal let stressAdjustment: Double

    /// Valence adjustment to apply during morning hours.
    /// Positive values improve mood (good sleep), negative values depress it.
    /// Range: approximately -0.075 to +0.075.
    internal let valenceAdjustment: Double

    // MARK: - Constants

    /// Composite score weights reflecting relative predictive power from sleep literature.
    private enum Weights {
        /// HRV weight: strongest predictor of autonomic recovery.
        static let hrv: Double = 0.30
        /// Duration weight: fundamental sleep adequacy measure.
        static let duration: Double = 0.25
        /// Deep sleep weight: restorative quality indicator.
        static let deepSleep: Double = 0.20
        /// Respiratory rate weight: autonomic tone during sleep.
        static let respRate: Double = 0.15
        /// Baseline offset ensuring non-zero contribution.
        static let constant: Double = 0.10

        // HRV-unavailable redistributed weights (each original scaled by 1.5)
        /// Duration weight when HRV is unavailable.
        static let durationNoHRV: Double = 0.375
        /// Deep sleep weight when HRV is unavailable.
        static let deepSleepNoHRV: Double = 0.30
        /// Respiratory rate weight when HRV is unavailable.
        static let respRateNoHRV: Double = 0.225
    }

    /// Reference values for sleep scoring.
    private enum SleepReference {
        /// Optimal sleep duration in hours for full score.
        static let optimalDurationHours: Double = 8.0
        /// Target deep sleep fraction for full score.
        static let optimalDeepSleepFraction: Double = 0.25
        /// Ideal baseline respiratory rate in breaths/min.
        static let idealRespRate: Double = 14.0
        /// Respiratory rate range over which score decays from 1 to 0.
        static let respRateDecayRange: Double = 10.0
        /// Default respiratory rate score when no data is available.
        static let defaultRespScore: Double = 0.7
        /// Minimum clamped HRV score.
        static let hrvScoreFloor: Double = 0.5
        /// Maximum clamped HRV score.
        static let hrvScoreCeiling: Double = 1.5
    }

    /// Scaling factors for converting composite to adjustments.
    private enum AdjustmentScale {
        /// Multiplier for stress adjustment.
        static let stress: Double = 0.2
        /// Multiplier for valence adjustment.
        static let valence: Double = 0.15
        /// Neutral composite score (no adjustment).
        static let neutralComposite: Double = 0.5
    }

    // MARK: - Computation

    /// Computes the morning mood baseline from overnight metrics.
    ///
    /// - Parameters:
    ///   - sleepDuration: Total sleep duration in hours.
    ///   - deepSleepPct: Deep sleep as a fraction (0.0-1.0).
    ///   - overnightHRV: Average HRV during the night (ms).
    ///   - baselineHRV: Personal or population HRV baseline (ms).
    ///   - overnightRespRate: Overnight respiratory rate in breaths/min (optional).
    /// - Returns: A `MorningMoodBaseline` with stress and valence adjustments.
    ///
    /// Reference: de Zambotti et al., MDPI Sensors 2023.
    internal static func compute(
        sleepDuration: Double,
        deepSleepPct: Double,
        overnightHRV: Double,
        baselineHRV: Double,
        overnightRespRate: Double?
    ) -> MorningMoodBaseline {
        // 1. Sleep duration score (0-1)
        // Reference: Kalmbach et al., Sleep Medicine Reviews 2018
        let durationScore = min(1.0, max(0.0, sleepDuration / SleepReference.optimalDurationHours))

        // 2. Deep sleep score (0-1) -- targets restorative slow-wave sleep
        let deepSleepScore = min(1.0, max(0.0, deepSleepPct / SleepReference.optimalDeepSleepFraction))

        // 3. Overnight HRV score (0.5-1.5 range, clamped)
        // When baselineHRV is unavailable (<= 0), the HRV component is skipped and
        // its weight is redistributed proportionally to the other signals.
        let hrvSleepScore: Double? = baselineHRV > 0
            ? min(SleepReference.hrvScoreCeiling, max(SleepReference.hrvScoreFloor, overnightHRV / baselineHRV))
            : nil

        // 4. Respiratory rate score (0-1)
        // Reference: Natarajan et al., npj Digital Medicine 2021
        let respScore: Double = {
            guard let rr = overnightRespRate else { return SleepReference.defaultRespScore }
            return min(1.0, max(0.0, 1.0 - (rr - SleepReference.idealRespRate) / SleepReference.respRateDecayRange))
        }()

        // 5. Composite score (weighted combination)
        // When HRV is unavailable, redistribute its weight proportionally
        // among the remaining scored components to preserve the total weight budget.
        let composite: Double
        if let hrvScore = hrvSleepScore {
            composite = durationScore * Weights.duration
                + deepSleepScore * Weights.deepSleep
                + hrvScore * Weights.hrv
                + respScore * Weights.respRate
                + Weights.constant
        } else {
            composite = durationScore * Weights.durationNoHRV
                + deepSleepScore * Weights.deepSleepNoHRV
                + respScore * Weights.respRateNoHRV
                + Weights.constant
        }

        // 6. Convert composite to adjustments
        // composite ~0.5 = neutral (no adjustment)
        // composite ~1.0 = excellent sleep -> stress -0.1, valence +0.075
        // composite ~0.0 = terrible sleep -> stress +0.1, valence -0.075
        let deviation = composite - AdjustmentScale.neutralComposite
        let stressAdj = -deviation * AdjustmentScale.stress
        let valenceAdj = deviation * AdjustmentScale.valence

        return MorningMoodBaseline(
            stressAdjustment: stressAdj,
            valenceAdjustment: valenceAdj
        )
    }
}

#endif
