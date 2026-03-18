//
//  LearningFormulaHelper.swift
//  Resonance
//
//  Shared EMA update logic used by both LearningStore (real-time)
//  and SongImpactCalculator (batch). Centralizes the two-tier learning
//  rate selection, EMA calculation, and confidence computation to
//  eliminate formula duplication.
//

#if os(iOS)

import Foundation
import CoreData

enum LearningFormulaHelper {

    // MARK: - Two-Tier Learning Rate

    /// Returns the appropriate EMA learning rate based on the sample count.
    /// Cold-start songs (fewer than `BackfillConstants.coldStartThreshold` plays)
    /// use a higher learning rate so the model converges faster. Established songs
    /// use the steady-state rate.
    ///
    /// - Parameters:
    ///   - sampleCount: Number of observations recorded so far.
    ///   - userLearningRate: Optional user-configured learning rate.
    ///     Falls back to `LearningConstants.defaultLearningRate` when nil.
    /// - Returns: The alpha value for the EMA update.
    static func learningRate(
        sampleCount: Int64,
        userLearningRate: Double? = nil
    ) -> Double {
        if sampleCount < Int64(BackfillConstants.coldStartThreshold) {
            return BackfillConstants.coldStartLearningRate  // 0.4
        }
        return userLearningRate ?? LearningConstants.defaultLearningRate  // 0.2
    }

    // MARK: - EMA Update

    /// Performs a single exponential moving average update.
    ///
    ///     new_value = (1 - alpha) * current + alpha * observed
    ///
    /// - Parameters:
    ///   - current: The current score.
    ///   - observed: The newly observed value.
    ///   - alpha: The learning rate (0 < alpha <= 1).
    /// - Returns: The updated score.
    static func emaUpdate(current: Double, observed: Double, alpha: Double) -> Double {
        (1.0 - alpha) * current + alpha * observed
    }

    // MARK: - Batch EMA Update (Four Dimensions)

    /// Updates all four SongEffect score dimensions using EMA.
    /// This is the canonical update path -- both LearningStore and
    /// SongImpactCalculator should call through here.
    ///
    /// - Parameters:
    ///   - effect: The SongEffect managed object to update.
    ///   - calm: Observed calm impact (0-1, centered at 0.5).
    ///   - energy: Observed energy impact (0-1, centered at 0.5).
    ///   - focus: Observed focus impact (0-1, centered at 0.5).
    ///   - moodLift: Observed mood lift impact (0-1, centered at 0.5).
    ///   - hasBiometricData: Whether biometric signals contributed.
    ///   - userLearningRate: Optional user-configured learning rate.
    static func updateEffect(
        _ effect: SongEffect,
        calm: Double,
        energy: Double,
        focus: Double,
        moodLift: Double,
        hasBiometricData: Bool,
        userLearningRate: Double? = nil
    ) {
        let alpha = learningRate(
            sampleCount: effect.sampleCount,
            userLearningRate: userLearningRate
        )

        effect.calmScore = emaUpdate(current: effect.calmScore, observed: calm, alpha: alpha)
        effect.energyScore = emaUpdate(current: effect.energyScore, observed: energy, alpha: alpha)
        effect.focusScore = emaUpdate(current: effect.focusScore, observed: focus, alpha: alpha)
        effect.moodLiftScore = emaUpdate(current: effect.moodLiftScore, observed: moodLift, alpha: alpha)

        effect.sampleCount += 1

        // Confidence: full at fullConfidenceSampleCount, capped without biometrics
        let maxConfidence = hasBiometricData ? 1.0 : BackfillConstants.behaviorOnlyMaxConfidence
        let fullSamples = Double(DecisionEngineConstants.fullConfidenceSampleCount)
        effect.confidenceLevel = min(maxConfidence, Double(effect.sampleCount) / fullSamples)

        effect.lastUpdatedAt = Date()
    }
}

#endif
