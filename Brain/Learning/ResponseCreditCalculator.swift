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
    ///   - personalHRVBaseline: Personal HRV baseline for normalization (Workstream 2.3).
    ///     When nil, falls back to fixed normalization factor.
    ///   - restingHR: Personal resting HR baseline for normalization (Workstream 2.3).
    ///     When nil, falls back to fixed normalization factor.
    ///   - hrvQuality: HRV sensor quality (0.0 - 1.0). Workstream 2.4.
    ///     When < 0.8, HRV credit is discounted by the quality factor.
    ///   - motionIntensity: Motion intensity (0.0 - 1.0). Workstream 2.2.
    ///     When > 0.5, biometric credit weights are reduced.
    /// - Returns: ResponseResult with calculated credits
    static func calculate(
        hrvDelta: Double,
        hrDelta: Double,
        hrAtStart: Double = 0,
        hrvAtStart: Double = 0,
        listenPercentage: Double,
        wasSkipped: Bool,
        preferences: UserPreferences = .load(),
        personalHRVBaseline: Double? = nil,
        restingHR: Double? = nil,
        hrvQuality: Double = 1.0,
        motionIntensity: Double = 0.0
    ) -> ResponseResult {
        // Determine biometric availability from start values, not deltas.
        // A delta of 0.0 is valid data meaning "no change", not "no data".
        let hasHRV = hrvAtStart > 0.0
        let hasHR = hrAtStart > 0.0
        let hasBiometricData = hasHRV || hasHR

        // Workstream 2.3: Use moving-window normalization with personal baselines
        let normalizedHRV = MovingWindowNormalizer.normalizeHRVWithFallback(
            delta: hrvDelta,
            personalBaseline: personalHRVBaseline
        )
        let normalizedHR = MovingWindowNormalizer.normalizeHRWithFallback(
            delta: hrDelta,
            restingHR: restingHR
        )

        // Workstream 2.2: Motion-aware discount factor for biometric signals
        let motionDiscount = motionIntensity > 0.5 ? (1.0 - motionIntensity) : 1.0

        // Completion bonus: songs listened past 50% get a bonus, under 50% get a penalty
        let completionBonus = (listenPercentage - LearningConstants.completionBonusThreshold) * 0.2

        // Skip penalty component (already handled separately by SkipPenaltyCalculator,
        // but we include a mild behavioral signal here)
        let skipSignal = wasSkipped ? -0.1 : 0.0

        // Calculate credits based on available biometric signals
        // Mirrors the four-mode pattern from ImpactScore.swift
        // Workstream 2.2: Apply motion discount to biometric components
        // Workstream 2.4: Apply HRV quality discount
        var calmCredit: Double
        var energyCredit: Double

        switch (hasHR, hasHRV) {
        case (true, true):
            // Full biometric data — use both signals, apply motion discount
            calmCredit = (normalizedHRV * 0.5 * motionDiscount) + (-normalizedHR * 0.3 * motionDiscount) + completionBonus + skipSignal
            energyCredit = (normalizedHR * 0.3 * motionDiscount) + completionBonus + skipSignal

        case (true, false):
            // HR only — redistribute HRV weight to completion
            calmCredit = (-normalizedHR * 0.4 * motionDiscount) + completionBonus * 1.5 + skipSignal
            energyCredit = (normalizedHR * 0.4 * motionDiscount) + completionBonus + skipSignal

        case (false, true):
            // HRV only — redistribute HR weight to HRV
            calmCredit = (normalizedHRV * 0.7 * motionDiscount) + completionBonus + skipSignal
            energyCredit = completionBonus + skipSignal

        case (false, false):
            // No biometric data — behavior only (no motion discount needed)
            calmCredit = completionBonus * 2.0 + skipSignal
            energyCredit = completionBonus * 2.0 + skipSignal
        }

        // Workstream 2.4: Apply HRV quality discount to calm credit
        // (calm is the dimension most dependent on HRV accuracy)
        calmCredit = SensorConfidenceScorer.applyQualityDiscount(
            credit: calmCredit,
            hrvQuality: hrvQuality
        )

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
