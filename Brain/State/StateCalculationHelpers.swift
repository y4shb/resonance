//
//  StateCalculationHelpers.swift
//  Resonance
//
//  Pure calculation functions for the StateEngine: arousal, stress, energy,
//  focus, valence, HR acceleration, and numeric utilities.
//  Extracted from StateEngine.swift to keep files under the 500-line limit.
//
//  Research citations:
//  - R1 Circadian HRV: Hernando et al., Sensors 2018; Boudreau et al., PMC 2022
//  - R2 Multi-signal valence: Kreibig, Cognition & Emotion 2010; Mauss & Robinson 2009
//  - R3 HR acceleration: Appelhans & Luecken, Psychophysiology 2006
//  - R6 Sleep-derived baseline: de Zambotti et al., MDPI Sensors 2023
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
    /// Enhanced with circadian HRV correction (R1) to prevent false-positive stress
    /// readings during natural afternoon HRV nadir.
    /// Reference: Boudreau et al., PMC 2022 -- diurnal HRV variation pattern
    func calculateStress(biometric: BiometricSignal?) -> EstimateResult {
        guard let hrv = biometric?.hrv, hrv > 0 else {
            return EstimateResult(value: 0.5, confidence: 0.0)
        }

        // Feed each HRV reading into the personal baseline tracker
        personalBaseline.recordObservation(hrv)

        // Use the personal baseline (adapts over 7-day rolling window,
        // falls back to population default of 50ms when insufficient data)
        let baselineHRV = personalBaseline.currentBaseline

        // R1: Apply circadian HRV correction before stress calculation.
        // Afternoon HRV is naturally ~15% lower; without correction this
        // causes false stress readings. (Hernando et al., Sensors 2018)
        let currentHour = Calendar.current.component(.hour, from: Date())
        let adjustedBaseline = baselineHRV * Self.circadianHRVFactor(for: currentHour)

        let ratio = hrv / adjustedBaseline

        // Map ratio to stress (inverse relationship):
        // ratio 0.5 (low HRV) -> stress ~0.7
        // ratio 1.0 (baseline) -> stress ~0.4
        // ratio 1.5 (high HRV) -> stress ~0.1
        let stress = Self.clamp(1.0 - (ratio * 0.6), 0.0, 1.0)

        let confidence = biometric?.sampleQuality ?? 0.5

        return EstimateResult(value: stress, confidence: confidence)
    }

    // MARK: - R1: Circadian HRV Baseline Adjustment

    /// Circadian HRV baseline adjustment factor.
    /// Based on population-average diurnal HRV pattern.
    /// Peak early morning, nadir afternoon ~14:00-15:00.
    /// Reference: Boudreau et al., PMC 2022; Hernando et al., Sensors 2018
    static func circadianHRVFactor(for hour: Int) -> Double {
        switch hour {
        case 0..<6:   return 1.15  // Early morning: HRV naturally elevated
        case 6..<10:  return 1.10  // Morning: still above average
        case 10..<14: return 1.00  // Late morning: baseline
        case 14..<18: return 0.85  // Afternoon: HRV naturally lower (nadir)
        case 18..<22: return 0.95  // Evening: recovering
        default:      return 1.05  // Night: rising with parasympathetic dominance
        }
    }

    // MARK: - Energy Calculation (plan.md Section 5.1.4)

    /// Energy = composite of arousal and inverse stress.
    /// Adjusted by circadian energy modifier (blended learned + static),
    /// sleep baseline modifier in the morning (Workstream 3.2), and
    /// sleep-derived mood baseline (R6).
    func calculateEnergy(arousal: Double, stress: Double) -> Double {
        var energy = (arousal * 0.6) + ((1.0 - stress) * 0.4)

        let hour = Calendar.current.component(.hour, from: Date())

        // Apply circadian energy modifier (blends learned profile with static fallback)
        let circadianModifier = circadianManager.blendedEnergyModifier(forHour: hour)
        energy += circadianModifier

        // Apply sleep baseline modifier during morning hours (Workstream 3.2)
        if hour >= 5 && hour < 12,
           let sleepBaseline = contextCollector.aggregatedContext.sleepBaseline {
            energy = Self.clamp(energy + sleepBaseline.morningEnergyModifier, 0.0, 1.0)
        }

        return Self.clamp(energy, 0.0, 1.0)
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

    // MARK: - R2: Multi-Signal Valence Calculation

    /// Enhanced valence (mood positivity) using multiple biometric signals.
    /// Previous version used stress-only: valence = 0.5 - stress * 0.3
    /// Now incorporates HRV trend, activity state, and sleep quality for
    /// a more accurate mood inference.
    /// Reference: Kreibig, Cognition & Emotion 2010; Mauss & Robinson, 2009
    ///
    /// - Parameters:
    ///   - stress: Current stress level (0-1)
    ///   - arousal: Current arousal level (0-1)
    ///   - biometric: Current biometric signal (optional)
    ///   - sleepBaseline: Last night's sleep baseline (optional)
    /// - Returns: Valence score (0-1), where higher = more positive mood
    func calculateValence(
        stress: Double,
        arousal: Double,
        biometric: BiometricSignal?,
        sleepBaseline: SleepBaseline?
    ) -> Double {
        // Stress component: negative influence on mood (R2 reweighted from 0.3 to 0.25)
        let stressComponent = -stress * 0.25

        // Activity bonus: exercise improves valence (Berger & Motl, 2000)
        let activityBonus: Double = (biometric?.isInWorkout == true) ? 0.1 : 0.0

        // HRV trend: rising HRV suggests improving autonomic balance and mood.
        // Uses recent HRV history from the personal baseline tracker.
        // (Appelhans & Luecken, Psychophysiology 2006)
        let hrvTrendComponent: Double = {
            guard let currentHRV = biometric?.hrv, currentHRV > 0 else { return 0.0 }
            let baseline = personalBaseline.currentBaseline
            let trend = (currentHRV - baseline) / 20.0
            return Self.clamp(trend * 0.10, -0.15, 0.15)
        }()

        // Sleep quality predicts next-day positive affect.
        // (de Zambotti et al., MDPI Sensors 2023)
        let sleepScore: Double = {
            guard let sleep = sleepBaseline else { return 0.5 }
            // Normalize sleep quality: 7+ hours and 20%+ deep sleep = good
            let durationNorm = Self.clamp(sleep.totalSleepHours / 8.0, 0.0, 1.0)
            let deepNorm = Self.clamp(sleep.deepSleepPercentage / 0.25, 0.0, 1.0)
            return durationNorm * 0.6 + deepNorm * 0.4
        }()
        let sleepComponent = (sleepScore - 0.5) * 0.05

        return Self.clamp(
            0.5 + stressComponent + activityBonus + hrvTrendComponent + sleepComponent,
            0.0,
            1.0
        )
    }

    /// Legacy valence calculation (stress-only) for backward compatibility.
    /// Prefer the multi-signal variant when biometric data is available.
    func calculateValence(stress: Double) -> Double {
        Self.clamp(0.5 - (stress * 0.3), 0.0, 1.0)
    }

    // MARK: - R3: HR Acceleration Rate for Transition Detection

    /// Calculates HR acceleration rate (BPM change per minute).
    /// Rapid changes (>5 BPM/min) indicate emotional state transitions
    /// such as onset of stress, excitement, or relaxation.
    /// Reference: Appelhans & Luecken, Psychophysiology 2006
    ///
    /// - Parameters:
    ///   - currentHR: Current heart rate in BPM
    ///   - hrSample2MinAgo: Heart rate sample from approximately 2 minutes ago
    /// - Returns: Rate of HR change in BPM per minute (positive = accelerating)
    static func calculateHRAcceleration(
        currentHR: Double,
        hrSample2MinAgo: Double?
    ) -> Double {
        guard let previousHR = hrSample2MinAgo else { return 0.0 }
        return (currentHR - previousHR) / 2.0
    }

    /// Computes a transition signal (0-1) from HR acceleration.
    /// Values above 0.0 indicate a likely emotional state transition.
    /// Can be added to existing change detection scoring.
    /// Reference: Appelhans & Luecken, Psychophysiology 2006
    ///
    /// - Parameter hrAcceleration: HR acceleration rate from `calculateHRAcceleration`
    /// - Returns: Transition signal strength (0-1), 0 = no transition detected
    static func transitionSignalFromHRAcceleration(_ hrAcceleration: Double) -> Double {
        let absAccel = abs(hrAcceleration)
        guard absAccel > 5.0 else { return 0.0 }
        return min(1.0, absAccel / 10.0)
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
