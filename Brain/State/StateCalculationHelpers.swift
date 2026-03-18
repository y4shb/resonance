//
//  StateCalculationHelpers.swift
//  Resonance
//
//  Pure calculation functions for the StateEngine: arousal, stress, energy,
//  focus, valence, and numeric utilities.
//  Extracted from StateEngine.swift to keep files under the 500-line limit.
//

#if os(iOS)

import Foundation

// MARK: - State Calculation Helpers

extension StateEngine {

    // MARK: - Arousal Calculation (plan.md Section 5.1.1)

    /// Calculates arousal (0-1) from heart rate using heart rate reserve method.
    /// When VO2 Max is available (Workstream 3.1), uses it to estimate a more
    /// accurate max HR, improving HR zone normalization for fit individuals.
    func calculateArousal(biometric: BiometricSignal?) -> EstimateResult {
        guard let hr = biometric?.heartRate, hr > 0 else {
            return EstimateResult(value: 0.5, confidence: 0.0)
        }

        let resting = restingHeartRate ?? StateEngineConstants.defaultRestingHeartRate
        let maxHR: Double

        // VO2 Max-adjusted max HR estimation (Workstream 3.1)
        // Higher VO2 Max indicates better fitness, allowing higher sustainable HR.
        // Adjusted formula: base max HR + fitness bonus
        if let vo2Max = cachedVO2Max, vo2Max > 0 {
            let baseMaxHR = StateEngineConstants.maxHeartRateBase
                - Double(StateEngineConstants.defaultUserAge)
            // Fitness bonus: VO2 Max above 40 adds capacity (capped at +10 BPM)
            let fitnessBonus = min(10.0, max(0.0, (vo2Max - 40.0) * 0.5))
            maxHR = baseMaxHR + fitnessBonus
        } else {
            maxHR = StateEngineConstants.maxHeartRateBase
                - Double(StateEngineConstants.defaultUserAge)
        }

        let hrReserve = maxHR - resting

        guard hrReserve > 0 else {
            return EstimateResult(value: 0.5, confidence: 0.3)
        }

        let normalizedHR = (hr - resting) / hrReserve
        let arousal = Self.clamp(normalizedHR, 0.0, 1.0)

        // Confidence based on signal quality; boost slightly if VO2 Max is available
        var confidence = biometric?.sampleQuality ?? 0.5
        if cachedVO2Max != nil {
            confidence = min(1.0, confidence + 0.05)
        }

        return EstimateResult(value: arousal, confidence: confidence)
    }

    // MARK: - Stress Calculation (plan.md Section 5.1.2)

    /// Calculates stress (0-1) from HRV. HRV is inversely correlated with stress.
    func calculateStress(biometric: BiometricSignal?) -> EstimateResult {
        guard let hrv = biometric?.hrv, hrv > 0 else {
            return EstimateResult(value: 0.5, confidence: 0.0)
        }

        // Feed each HRV reading into the personal baseline tracker
        personalBaseline.recordObservation(hrv)

        // Use the personal baseline (adapts over 7-day rolling window,
        // falls back to population default of 50ms when insufficient data)
        let baselineHRV = personalBaseline.currentBaseline

        let ratio = hrv / baselineHRV

        // Map ratio to stress (inverse relationship):
        // ratio 0.5 (low HRV) -> stress ~0.7
        // ratio 1.0 (baseline) -> stress ~0.4
        // ratio 1.5 (high HRV) -> stress ~0.1
        let stress = Self.clamp(1.0 - (ratio * 0.6), 0.0, 1.0)

        let confidence = biometric?.sampleQuality ?? 0.5

        return EstimateResult(value: stress, confidence: confidence)
    }

    // MARK: - Energy Calculation (plan.md Section 5.1.4)

    /// Energy = composite of arousal and inverse stress.
    /// Adjusted by sleep baseline modifier in the morning (Workstream 3.2).
    func calculateEnergy(arousal: Double, stress: Double) -> Double {
        var energy = (arousal * 0.6) + ((1.0 - stress) * 0.4)

        // Apply sleep baseline modifier during morning hours (Workstream 3.2)
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12,
           let sleepBaseline = contextCollector.aggregatedContext.sleepBaseline {
            energy = Self.clamp(energy + sleepBaseline.morningEnergyModifier, 0.0, 1.0)
        }

        return energy
    }

    // MARK: - Focus Calculation (plan.md Section 5.1.4)

    /// Focus depends on context and stress level.
    func calculateFocus(stress: Double, arousal: Double, context: ActivityContext) -> Double {
        switch context {
        case .deepWork:
            return Self.clamp(0.8 - (stress * 0.3), 0.0, 1.0)
        case .work:
            return Self.clamp(0.6 - (stress * 0.2), 0.0, 1.0)
        case .workout:
            return 0.3  // Physical focus, not mental
        case .preSleep:
            return Self.clamp(0.3 - (arousal * 0.2), 0.0, 1.0)
        default:
            let base = 0.5 - (stress * 0.2)
            let lowArousalBonus = arousal < 0.4 ? 0.1 : 0.0
            return Self.clamp(base + lowArousalBonus, 0.0, 1.0)
        }
    }

    // MARK: - Valence Calculation (plan.md Section 5.1.4)

    /// Valence (mood positivity). Default neutral, adjusted by stress, blended with manual input.
    func calculateValence(stress: Double) -> Double {
        Self.clamp(0.5 - (stress * 0.3), 0.0, 1.0)
    }

    // MARK: - Numeric Utilities

    static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    static func blend(_ a: Double, _ b: Double, weight: Double) -> Double {
        a * (1.0 - weight) + b * weight
    }
}

#endif
