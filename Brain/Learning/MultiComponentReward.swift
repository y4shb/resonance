//
//  MultiComponentReward.swift
//  Resonance
//
//  Multi-component reward function that combines HRV, HR, behavioral,
//  and session-quality signals into a single composite reward value.
//
//  Workstream 2.1: Implements R_total = w1*R_hrv + w2*R_hr + w3*R_behavioral + w4*R_session
//
//  Weight profiles:
//    Cold-start (< 50 interactions): behavioral-heavy (w1=0.2, w2=0.1, w3=0.6, w4=0.1)
//    Established (>= 50 interactions): biometric-heavy (w1=0.4, w2=0.2, w3=0.2, w4=0.2)
//
//  Transition is smooth sigmoid blend around the threshold.
//

#if os(iOS)

import Foundation

// MARK: - Reward Component

/// Individual reward component with its computed value and confidence.
struct RewardComponent {
    /// The component's reward value (0.0 - 1.0)
    let value: Double
    /// Confidence in this component's measurement (0.0 - 1.0)
    let confidence: Double
    /// Whether this component had valid input data
    let isAvailable: Bool

    static let unavailable = RewardComponent(value: 0.5, confidence: 0.0, isAvailable: false)
}

// MARK: - Reward Weights

/// Weight configuration for the multi-component reward function.
struct RewardWeights {
    let hrv: Double
    let hr: Double
    let behavioral: Double
    let session: Double

    /// Cold-start weights: behavioral-heavy because biometric history is sparse.
    static let coldStart = RewardWeights(hrv: 0.2, hr: 0.1, behavioral: 0.6, session: 0.1)

    /// Established user weights: biometric-heavy because we have reliable baselines.
    static let established = RewardWeights(hrv: 0.4, hr: 0.2, behavioral: 0.2, session: 0.2)

    /// Blends between cold-start and established weights using a sigmoid transition.
    /// - Parameter interactionCount: Total number of song interactions for this user.
    /// - Returns: Blended weights appropriate for the user's maturity level.
    static func blended(interactionCount: Int) -> RewardWeights {
        let t = transitionFactor(interactionCount: interactionCount)
        return RewardWeights(
            hrv: coldStart.hrv * (1.0 - t) + established.hrv * t,
            hr: coldStart.hr * (1.0 - t) + established.hr * t,
            behavioral: coldStart.behavioral * (1.0 - t) + established.behavioral * t,
            session: coldStart.session * (1.0 - t) + established.session * t
        )
    }

    /// Sigmoid transition factor from cold-start to established.
    /// Returns 0.0 for brand-new users, 1.0 for well-established users,
    /// with a smooth S-curve centered at the threshold.
    /// - Parameter interactionCount: Total song interactions.
    /// - Returns: Factor in [0.0, 1.0].
    private static func transitionFactor(interactionCount: Int) -> Double {
        let threshold = Double(MultiComponentRewardConstants.establishedThreshold)
        let steepness = MultiComponentRewardConstants.transitionSteepness
        let x = Double(interactionCount)
        // Sigmoid: 1 / (1 + exp(-steepness * (x - threshold)))
        return 1.0 / (1.0 + exp(-steepness * (x - threshold)))
    }
}

// MARK: - Constants

enum MultiComponentRewardConstants {
    /// Number of song interactions before transitioning to established weights.
    static let establishedThreshold: Int = 50

    /// Steepness of the sigmoid transition curve.
    /// At 0.1, the transition spans roughly 20 interactions around the threshold.
    static let transitionSteepness: Double = 0.1

    /// Significant HRV change threshold as a fraction of personal baseline.
    static let significantHRVChangeFraction: Double = 0.2

    /// Significant HR change threshold in BPM.
    static let significantHRChangeBPM: Double = 10.0
}

// MARK: - Multi-Component Reward Calculator

/// Computes a composite reward from four independent signal channels.
///
/// The composite reward adapts its weighting based on the user's interaction
/// history, shifting from behavioral signals (skips, listen percentage) during
/// cold-start to biometric signals (HRV, HR) once sufficient baseline data exists.
struct MultiComponentRewardCalculator {

    // MARK: - Composite Reward

    /// Computes the total composite reward for a playback event.
    ///
    /// - Parameters:
    ///   - hrvComponent: HRV-derived reward component.
    ///   - hrComponent: Heart rate-derived reward component.
    ///   - behavioralComponent: Behavioral reward (skip/listen/feedback).
    ///   - sessionComponent: Session arc adherence reward.
    ///   - interactionCount: User's total interaction count for weight selection.
    ///   - motionIntensity: Current motion intensity (0.0 - 1.0). When > 0.5,
    ///     biometric weights are discounted (see Task 2.2).
    ///   - hrvQuality: HRV sensor confidence (0.0 - 1.0). When < 0.8,
    ///     HRV component is discounted (see Task 2.4).
    /// - Returns: Composite reward value in [0.0, 1.0].
    static func computeCompositeReward(
        hrvComponent: RewardComponent,
        hrComponent: RewardComponent,
        behavioralComponent: RewardComponent,
        sessionComponent: RewardComponent,
        interactionCount: Int,
        motionIntensity: Double = 0.0,
        hrvQuality: Double = 1.0
    ) -> Double {
        var weights = RewardWeights.blended(interactionCount: interactionCount)

        // Task 2.2: Motion-aware reward gating
        // When motion is vigorous, biometric signals become unreliable.
        if motionIntensity > 0.5 {
            let motionDiscount = 1.0 - motionIntensity
            weights = RewardWeights(
                hrv: weights.hrv * motionDiscount,
                hr: weights.hr * motionDiscount,
                behavioral: weights.behavioral,
                session: weights.session
            )
        }

        // Task 2.4: HRV quality gating
        // Low-quality HRV samples get discounted.
        var effectiveHRVValue = hrvComponent.value
        if hrvQuality < 0.8 {
            effectiveHRVValue = 0.5 + (effectiveHRVValue - 0.5) * hrvQuality
        }

        // Compute raw weighted sum
        let rawReward = weights.hrv * effectiveHRVValue
            + weights.hr * hrComponent.value
            + weights.behavioral * behavioralComponent.value
            + weights.session * sessionComponent.value

        // Normalize by total weight to handle motion-discounted weights
        let totalWeight = weights.hrv + weights.hr + weights.behavioral + weights.session
        guard totalWeight > 0 else { return 0.5 }

        let normalizedReward = rawReward / totalWeight
        return clamp(normalizedReward)
    }

    // MARK: - Component Calculators

    /// Computes the HRV reward component.
    ///
    /// Uses personal baseline normalization (Task 2.3):
    ///   normalizedHRV = hrvDelta / (personalHRVBaseline * significantChangeFraction)
    ///
    /// - Parameters:
    ///   - hrvDelta: Change in HRV during playback.
    ///   - personalBaseline: User's personal HRV baseline value.
    ///   - musicNeed: Current music need for context-dependent interpretation.
    /// - Returns: HRV reward component.
    static func computeHRVReward(
        hrvDelta: Double?,
        personalBaseline: Double,
        musicNeed: MusicNeed
    ) -> RewardComponent {
        guard let delta = hrvDelta else {
            return .unavailable
        }

        let significantChange = personalBaseline * MultiComponentRewardConstants.significantHRVChangeFraction
        guard significantChange > 0 else {
            return RewardComponent(value: 0.5, confidence: 0.3, isAvailable: true)
        }

        let normalizedDelta = delta / significantChange

        let value: Double
        switch musicNeed {
        case .calm, .focus:
            // Positive HRV delta = relaxation = good
            value = 0.5 + normalizedDelta * 0.25
        case .energize:
            // Negative HRV delta = activation = expected
            value = 0.5 - normalizedDelta * 0.15
        case .maintain, .transition:
            // Minimal change is ideal
            value = 0.5 - abs(normalizedDelta) * 0.10
        }

        return RewardComponent(
            value: clamp(value),
            confidence: 0.9,
            isAvailable: true
        )
    }

    /// Computes the HR reward component.
    ///
    /// - Parameters:
    ///   - hrDelta: Change in heart rate during playback.
    ///   - musicNeed: Current music need for context-dependent interpretation.
    /// - Returns: HR reward component.
    static func computeHRReward(
        hrDelta: Double?,
        musicNeed: MusicNeed
    ) -> RewardComponent {
        guard let delta = hrDelta else {
            return .unavailable
        }

        let normalizedDelta = delta / MultiComponentRewardConstants.significantHRChangeBPM

        let value: Double
        switch musicNeed {
        case .energize:
            // Rising HR during energize = good
            value = 0.5 + normalizedDelta * 0.20
        case .calm:
            // Rising HR during calm = bad
            value = 0.5 - normalizedDelta * 0.20
        case .focus:
            // Stable HR during focus = good
            value = 0.5 - abs(normalizedDelta) * 0.10
        case .maintain, .transition:
            value = 0.5
        }

        return RewardComponent(
            value: clamp(value),
            confidence: 0.8,
            isAvailable: true
        )
    }

    /// Computes the behavioral reward component from skip, listen, and feedback signals.
    ///
    /// - Parameters:
    ///   - wasSkipped: Whether the song was skipped.
    ///   - listenPercentage: Fraction of the song listened to (0.0 - 1.0).
    ///   - explicitFeedback: Optional user feedback (0.0 - 1.0).
    /// - Returns: Behavioral reward component.
    static func computeBehavioralReward(
        wasSkipped: Bool,
        listenPercentage: Double,
        explicitFeedback: Double?
    ) -> RewardComponent {
        var value = 0.5

        // Skip penalty (tiered)
        if wasSkipped {
            if listenPercentage < BackfillConstants.earlySkipThreshold {
                value -= 0.30
            } else if listenPercentage < LearningConstants.minimumListenPercentage {
                value -= 0.15
            } else {
                value -= 0.075
            }
        } else if listenPercentage > 0.90 {
            // Completion bonus
            value += 0.15
        } else if listenPercentage > LearningConstants.completionBonusThreshold {
            // Partial completion bonus
            value += (listenPercentage - LearningConstants.completionBonusThreshold) * 0.2
        }

        // Explicit feedback override
        if let feedback = explicitFeedback {
            value = value * 0.4 + feedback * 0.6
        }

        return RewardComponent(
            value: clamp(value),
            confidence: 1.0,
            isAvailable: true
        )
    }

    /// Computes the session arc reward component.
    ///
    /// - Parameters:
    ///   - sessionScore: Current session quality score (0.0 - 1.0).
    ///   - arcAdherence: How well the song adhered to the planned arc (0.0 - 1.0).
    /// - Returns: Session reward component.
    static func computeSessionReward(
        sessionScore: Double,
        arcAdherence: Double
    ) -> RewardComponent {
        // Blend session quality with arc adherence
        let value = sessionScore * 0.5 + arcAdherence * 0.5

        return RewardComponent(
            value: clamp(value),
            confidence: 0.7,
            isAvailable: true
        )
    }

    // MARK: - Helpers

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}

#endif
