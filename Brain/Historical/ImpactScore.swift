//
//  ImpactScore.swift
//  Resonance
//
//  Intermediate value type representing the immediate biometric/behavioral
//  impact of a single playback event.
//

import Foundation
import CoreData

/// Intermediate value type representing the immediate biometric/behavioral
/// impact of a single playback event. Used by SongImpactCalculator to
/// EMA-update SongEffect records.
///
/// All values range from 0.0 to 1.0, centered at 0.5.
struct ImpactScore {
    /// Calming effect: higher means the song induced relaxation
    let calm: Double

    /// Energizing effect: higher means the song induced activation
    let energy: Double

    /// Focus effect: higher means the song held attention
    let focus: Double

    /// Mood lift effect: derived from behavioral signals
    let moodLift: Double

    /// Whether the song was skipped
    let wasSkipped: Bool

    /// Whether biometric data was available for this calculation
    let hasBiometricData: Bool

    /// Clamp a value to [0, 1]
    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    /// Calculate an ImpactScore from a PlaybackEvent's stored values.
    ///
    /// Uses two-tier skip penalty:
    /// - Early skip (<15% listened): full penalty (-0.3)
    /// - Late skip (15-30%): reduced penalty (-0.15)
    ///
    /// Biometric signal redistribution:
    /// - Both HR + HRV available: standard weights
    /// - HR only: redistribute HRV weight to HR
    /// - HRV only: redistribute HR weight to HRV
    /// - Neither: behavior-only scoring
    static func calculate(from event: PlaybackEvent) -> ImpactScore {
        let hrvDelta = event.hrvDelta
        let hrDelta = event.hrDelta
        let listenPct = event.listenPercentage
        let wasSkipped = event.wasSkipped

        // Determine biometric availability by checking whether start values
        // were recorded (non-zero start means the sensor was active).
        // A delta of 0.0 is valid data meaning "no change", not "no data".
        let hasHR = event.hrAtStart > 0.0
        let hasHRV = event.hrvAtStart > 0.0
        let hasBiometric = hasHR || hasHRV

        // Normalize biometric signals
        let hrvImpact = hrvDelta / LearningConstants.hrvNormalizationFactor
        let hrImpact = hrDelta / LearningConstants.hrNormalizationFactor

        // Two-tier skip penalty
        let skipPenalty: Double
        if wasSkipped {
            if listenPct < BackfillConstants.earlySkipThreshold {
                skipPenalty = -LearningConstants.skipPenaltyMultiplier  // -0.3
            } else {
                skipPenalty = -BackfillConstants.lateSkipPenalty  // -0.15
            }
        } else {
            skipPenalty = 0.0
        }

        // Completion bonus (scales from -0.1 to +0.1)
        let completionBonus = (listenPct - LearningConstants.completionBonusThreshold) * 0.2

        // Calculate scores based on biometric availability
        let calmRaw: Double
        let energyRaw: Double

        switch (hasHR, hasHRV) {
        case (true, true):
            // Both available: standard weights
            calmRaw = 0.5 + (hrvImpact * 0.5) + (-hrImpact * 0.3) + completionBonus + skipPenalty
            energyRaw = 0.5 + (hrImpact * 0.3) + completionBonus + skipPenalty
        case (true, false):
            // HR only: redistribute HRV weight to completion/behavior
            calmRaw = 0.5 + (-hrImpact * 0.5) + completionBonus * 1.5 + skipPenalty
            energyRaw = 0.5 + (hrImpact * 0.5) + completionBonus + skipPenalty
        case (false, true):
            // HRV only: redistribute HR weight to HRV
            calmRaw = 0.5 + (hrvImpact * 0.7) + completionBonus + skipPenalty
            energyRaw = 0.5 + completionBonus * 1.5 + skipPenalty
        case (false, false):
            // No biometrics: behavior-only
            calmRaw = 0.5 + completionBonus * 2.0 + skipPenalty
            energyRaw = 0.5 + completionBonus * 2.0 + skipPenalty
        }

        // Focus is always behavior-based (listen engagement)
        let focusRaw = 0.5 + completionBonus + (wasSkipped ? skipPenalty * 0.5 : 0.0)

        // Mood lift derived from behavioral signals
        let moodLiftRaw = 0.5 + completionBonus * 1.5 + skipPenalty

        return ImpactScore(
            calm: clamp(calmRaw),
            energy: clamp(energyRaw),
            focus: clamp(focusRaw),
            moodLift: clamp(moodLiftRaw),
            wasSkipped: wasSkipped,
            hasBiometricData: hasBiometric
        )
    }
}
