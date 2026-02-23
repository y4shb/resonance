//
//  ResponseCreditCalculator.swift
//  Resonance
//
//  Calculates biometric response credit/penalty based on HRV and HR changes during playback.
//  Positive HRV delta (relaxation response) credits calm score.
//  Positive HR delta (activation response) credits energy score.
//

#if os(iOS)

import Foundation

/// Calculates biometric response credit/penalty based on HRV and HR changes during playback.
/// Positive HRV delta (relaxation response) credits calm score.
/// Positive HR delta (activation response) credits energy score.
struct ResponseCreditCalculator {

    /// Result of a biometric response calculation.
    struct ResponseResult {
        /// Credit/penalty for calm score. Positive = song was calming.
        let calmCredit: Double
        /// Credit/penalty for energy score. Positive = song was energizing.
        let energyCredit: Double
        /// Credit/penalty for focus score (based on listen completion).
        let focusCredit: Double
        /// Credit/penalty for mood lift / valence (engagement-weighted, behavior-driven).
        let valenceCredit: Double
        /// Whether biometric data was available
        let hasBiometricData: Bool
        /// Maximum confidence this result can contribute (0.7 if no biometrics, 1.0 if biometrics present)
        let maxConfidence: Double
        /// Weight factor from user preferences (hrvResponseWeight)
        let userWeight: Double
        /// Calm credit weighted by user's HRV response weight preference.
        var weightedCalmCredit: Double { calmCredit * userWeight }
        /// Energy credit weighted by user's HRV response weight preference.
        var weightedEnergyCredit: Double { energyCredit * userWeight }
    }

    /// Calculate biometric response credit for a playback event.
    /// - Parameters:
    ///   - hrvDelta: Change in HRV during playback (positive = relaxation)
    ///   - hrDelta: Change in heart rate during playback (positive = activation)
    ///   - listenPercentage: How much of the song was listened to (0.0 - 1.0)
    ///   - wasSkipped: Whether the song was skipped
    ///   - preferences: User preferences for response weight
    /// - Returns: ResponseResult with calculated credits
    static func calculate(
        hrvDelta: Double,
        hrDelta: Double,
        listenPercentage: Double,
        wasSkipped: Bool,
        preferences: UserPreferences = .load()
    ) -> ResponseResult {
        let hasHRV = abs(hrvDelta) > 0.001
        let hasHR = abs(hrDelta) > 0.001
        let hasBiometricData = hasHRV || hasHR

        // Normalize biometric deltas using constants from plan.md
        let normalizedHRV = hrvDelta / LearningConstants.hrvNormalizationFactor  // 10ms = significant
        let normalizedHR = hrDelta / LearningConstants.hrNormalizationFactor     // 10bpm = significant

        // Completion bonus: songs listened past 50% get a bonus, under 50% get a penalty
        let completionBonus = (listenPercentage - LearningConstants.completionBonusThreshold) * 0.2

        // Skip penalty component (already handled separately by SkipPenaltyCalculator,
        // but we include a mild behavioral signal here)
        let skipSignal = wasSkipped ? -0.1 : 0.0

        // Calculate credits based on available biometric signals
        // Mirrors the four-mode pattern from ImpactScore.swift
        let calmCredit: Double
        let energyCredit: Double

        switch (hasHR, hasHRV) {
        case (true, true):
            // Full biometric data — use both signals
            calmCredit = (normalizedHRV * 0.5) + (-normalizedHR * 0.3) + completionBonus + skipSignal
            energyCredit = (normalizedHR * 0.3) + completionBonus + skipSignal

        case (true, false):
            // HR only — redistribute HRV weight to completion
            calmCredit = (-normalizedHR * 0.4) + completionBonus * 1.5 + skipSignal
            energyCredit = (normalizedHR * 0.4) + completionBonus + skipSignal

        case (false, true):
            // HRV only — redistribute HR weight to HRV
            calmCredit = (normalizedHRV * 0.7) + completionBonus + skipSignal
            energyCredit = completionBonus + skipSignal

        case (false, false):
            // No biometric data — behavior only
            calmCredit = completionBonus * 2.0 + skipSignal
            energyCredit = completionBonus * 2.0 + skipSignal
        }

        // Focus credit is primarily behavior-driven
        let focusCredit = completionBonus + skipSignal

        // Valence / mood-lift credit: stronger completion weight, matching ImpactScore.swift batch pattern
        let valenceCredit = completionBonus * 1.5 + skipSignal

        // Weight by listen duration — partial listens contribute less
        let durationWeight = min(1.0, listenPercentage * 1.5)  // Full weight at ~67% listen

        // Max confidence depends on biometric availability
        let maxConfidence = hasBiometricData ? 1.0 : BackfillConstants.behaviorOnlyMaxConfidence

        return ResponseResult(
            calmCredit: calmCredit * durationWeight,
            energyCredit: energyCredit * durationWeight,
            focusCredit: focusCredit * durationWeight,
            valenceCredit: valenceCredit * durationWeight,
            hasBiometricData: hasBiometricData,
            maxConfidence: maxConfidence,
            userWeight: preferences.hrvResponseWeight
        )
    }
}

#endif
