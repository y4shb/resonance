//
//  EmotionRefinementEngine.swift
//  Resonance
//
//  iPhone-side refinement of Watch emotion classification.
//  Adjusts valence based on detected emotional state and integrates
//  overnight temperature data into next-day energy/stress priors.
//

#if os(iOS)

import Foundation

// MARK: - Emotion Refinement Engine

/// Refines Watch-side emotion classification with additional iPhone context.
///
/// Integrates overnight temperature data for next-day energy and stress
/// adjustments, and applies contextual overrides (focus mode, workouts)
/// to the raw Watch emotion classification.
internal final class EmotionRefinementEngine {

    // MARK: - Constants

    /// Temperature deviation thresholds in degrees Celsius.
    private enum TempDeviation {
        /// Significant deviation indicating possible illness/stress.
        static let significant: Double = 0.5
        /// Notable deviation warranting moderate adjustment.
        static let notable: Double = 0.3
    }

    /// Energy prior adjustments based on temperature deviation.
    private enum EnergyPriors {
        /// Large energy reduction for significant temperature deviation.
        static let significantReduction: Double = -0.15
        /// Moderate energy reduction for notable deviation.
        static let moderateReduction: Double = -0.08
        /// Slight boost for below-baseline temperature (recovery).
        static let recoveryBoost: Double = 0.05
    }

    /// Stress prior adjustments based on temperature trend.
    private enum StressPriors {
        /// Stress increase for rising temperature trend.
        static let risingStress: Double = 0.08
        /// Stress reduction for falling temperature trend.
        static let fallingRelief: Double = -0.05
    }

    /// Time windows for temperature prior applicability.
    private enum TimeWindows {
        /// Temperature priors expire after 12 hours (in seconds).
        static let priorExpirySeconds: TimeInterval = 43_200
        /// Earliest hour for morning energy adjustment.
        static let morningStartHour: Int = 5
        /// Latest hour for morning energy adjustment (exclusive).
        static let morningEndHour: Int = 14
    }

    /// Minimum confidence for applying emotion-based valence refinement.
    private static let minimumEmotionConfidence: Double = 0.3

    /// Thresholds for contextual emotion overrides.
    private enum OverrideThresholds {
        /// Stress below this allows workout excited override.
        static let workoutStress: Double = 0.6
        /// Energy prior below this triggers fatigue override.
        static let fatigueEnergyPrior: Double = -0.1
        /// Energy below this triggers fatigue override.
        static let fatigueEnergy: Double = 0.4
    }

    // MARK: - Overnight Temperature State

    /// Latest overnight temperature packet received from Watch.
    private(set) var latestOvernightTemp: OvernightTemperaturePacket?

    /// Date when overnight temperature was last processed.
    private var lastTempProcessDate: Date?

    // MARK: - Temperature Priors

    /// Energy prior adjustment based on overnight temperature deviation.
    /// Negative = elevated temp, positive = recovery boost.
    private(set) var temperatureEnergyPrior: Double = 0.0

    /// Stress prior adjustment based on overnight temperature trend.
    private(set) var temperatureStressPrior: Double = 0.0

    // MARK: - Initialization

    init() {
        logInfo("EmotionRefinementEngine initialized", category: .stateEngine)
    }

    // MARK: - Valence Refinement

    /// Adjusts valence based on the detected emotional state.
    ///
    /// - Parameters:
    ///   - baseValence: The unrefined valence value (0.0-1.0).
    ///   - emotionalState: The Watch-detected emotional state, if available.
    ///   - confidence: Classification confidence from the Watch (0.0-1.0).
    /// - Returns: The adjusted valence, clamped to [0, 1].
    internal func refineValence(
        baseValence: Double,
        emotionalState: EmotionalState?,
        confidence: Double
    ) -> Double {
        guard let state = emotionalState,
              confidence > Self.minimumEmotionConfidence else {
            return baseValence
        }

        let adjustment = state.valenceAdjustment * confidence
        let refined = clamp(baseValence + adjustment, 0.0, 1.0)

        logDebug(
            "Valence refined: \(String(format: "%.2f", baseValence)) -> "
            + "\(String(format: "%.2f", refined)) "
            + "(emotion=\(state.rawValue), conf=\(String(format: "%.2f", confidence)))",
            category: .stateEngine
        )

        return refined
    }

    // MARK: - Overnight Temperature Integration

    /// Processes a new overnight temperature packet from the Watch.
    ///
    /// Updates energy and stress priors based on the temperature deviation
    /// magnitude and trend direction.
    ///
    /// - Parameter packet: The overnight temperature data from the Watch.
    internal func processOvernightTemperature(_ packet: OvernightTemperaturePacket) {
        latestOvernightTemp = packet

        // Energy prior: elevated temp suggests reduced energy
        if packet.deviation > TempDeviation.significant {
            temperatureEnergyPrior = EnergyPriors.significantReduction
        } else if packet.deviation > TempDeviation.notable {
            temperatureEnergyPrior = EnergyPriors.moderateReduction
        } else if packet.deviation < -TempDeviation.notable {
            temperatureEnergyPrior = EnergyPriors.recoveryBoost
        } else {
            temperatureEnergyPrior = 0.0
        }

        // Stress prior: rising trend suggests elevated stress
        let trend = TemperatureTrend(rawValue: packet.trend) ?? .stable
        switch trend {
        case .rising:
            temperatureStressPrior = StressPriors.risingStress
        case .falling:
            temperatureStressPrior = StressPriors.fallingRelief
        case .stable:
            temperatureStressPrior = 0.0
        }

        lastTempProcessDate = Date()

        logInfo(
            "Overnight temp processed: deviation=\(String(format: "%+.2f", packet.deviation))C, "
            + "trend=\(packet.trend), "
            + "energyPrior=\(String(format: "%+.2f", temperatureEnergyPrior)), "
            + "stressPrior=\(String(format: "%+.2f", temperatureStressPrior))",
            category: .stateEngine
        )
    }

    /// Returns the energy adjustment for the current morning based on temperature data.
    ///
    /// Only applies during morning hours and within 12 hours of the temperature reading.
    /// The adjustment decays linearly from full effect to zero over the expiry window.
    ///
    /// - Returns: Energy adjustment to apply, or 0.0 if not applicable.
    internal func morningEnergyAdjustment() -> Double {
        guard let tempDate = lastTempProcessDate else { return 0.0 }

        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= TimeWindows.morningStartHour && hour < TimeWindows.morningEndHour else {
            return 0.0
        }

        let elapsed = Date().timeIntervalSince(tempDate)
        guard elapsed < TimeWindows.priorExpirySeconds else { return 0.0 }

        let decayFactor = max(0.0, 1.0 - (elapsed / TimeWindows.priorExpirySeconds))
        return temperatureEnergyPrior * decayFactor
    }

    /// Returns the stress adjustment based on temperature data.
    ///
    /// Decays linearly over the prior expiry window.
    ///
    /// - Returns: Stress adjustment to apply, or 0.0 if expired.
    internal func stressAdjustment() -> Double {
        guard let tempDate = lastTempProcessDate else { return 0.0 }

        let elapsed = Date().timeIntervalSince(tempDate)
        guard elapsed < TimeWindows.priorExpirySeconds else { return 0.0 }

        let decayFactor = max(0.0, 1.0 - (elapsed / TimeWindows.priorExpirySeconds))
        return temperatureStressPrior * decayFactor
    }

    // MARK: - Emotional State Refinement

    /// Produces a refined emotional state by considering iPhone-side context.
    ///
    /// Applies contextual overrides:
    /// - Focus mode: prefers `.focused` when Watch reports calm or focused.
    /// - Workout: prefers `.excited` over `.stressed` when stress is moderate.
    /// - Temperature: overrides `.calm` to `.fatigued` when overnight temp was elevated.
    ///
    /// - Parameters:
    ///   - watchState: The Watch-classified emotional state.
    ///   - watchConfidence: Classification confidence (0.0-1.0).
    ///   - currentStress: Current stress level from the state engine.
    ///   - currentEnergy: Current energy level from the state engine.
    ///   - isFocusModeActive: Whether the device Focus mode is active.
    ///   - isInWorkout: Whether a workout session is in progress.
    /// - Returns: The refined emotional state, or `nil` if no Watch state.
    internal func refineEmotionalState(
        watchState: EmotionalState?,
        watchConfidence: Double,
        currentStress: Double,
        currentEnergy: Double,
        isFocusModeActive: Bool,
        isInWorkout: Bool
    ) -> EmotionalState? {
        guard let state = watchState else { return nil }

        if isFocusModeActive && (state == .calm || state == .focused) {
            return .focused
        }

        if isInWorkout && state == .stressed && currentStress < OverrideThresholds.workoutStress {
            return .excited
        }

        if temperatureEnergyPrior < OverrideThresholds.fatigueEnergyPrior
            && state == .calm
            && currentEnergy < OverrideThresholds.fatigueEnergy {
            return .fatigued
        }

        return state
    }

    // MARK: - Private Helpers

    /// Clamps a value to the specified range.
    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}

#endif
