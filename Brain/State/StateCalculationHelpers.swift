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

        // Tanaka formula: maxHR = 208 - 0.7 * age (Tanaka et al., JACC 2001)
        // More accurate than 220-age across all age groups. Meta-analysis of 18,712 subjects.
        // VO2 Max fitness bonus: athletes with VO2Max > 40 get up to +10 BPM headroom.
        let age = Double(StateEngineConstants.defaultUserAge)
        let baseMaxHR = StateEngineConstants.maxHeartRateBase
            - StateEngineConstants.maxHeartRateAgeCoefficient * age

        if let vo2Max = cachedVO2Max, vo2Max > 0 {
            let fitnessBonus = min(10.0, max(0.0, (vo2Max - 40.0) * 0.5))
            maxHR = baseMaxHR + fitnessBonus
        } else {
            maxHR = baseMaxHR
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

        // Map ratio to stress using logarithmic relationship for physiological accuracy.
        // HRV-stress is nonlinear (Shaffer & Ginsberg, 2017): initial drops from
        // baseline are more significant than further drops from already-low HRV.
        // Baseline (ratio=1.0) maps to 0.35 stress (moderate-low, not neutral 0.5)
        // per literature: a person at their personal HRV norm is in a low-moderate
        // stress state, not a midpoint state.
        //
        // ratio 0.5 → stress = 0.35 + 0.5 = 0.85 (high stress)
        // ratio 1.0 → stress = 0.35 - 0  = 0.35 (baseline, moderate-low)
        // ratio 1.5 → stress = 0.35 - 0.29 = 0.06 (very relaxed)
        // ratio 2.0 → stress = 0.35 - 0.5 = clamped to 0 (deeply relaxed)
        let logRatio = log(ratio) / log(2.0)  // log base 2
        let stress = Self.clamp(0.35 - 0.5 * logRatio, 0.0, 1.0)

        let confidence = biometric?.sampleQuality ?? 0.5

        return EstimateResult(value: stress, confidence: confidence)
    }

    // MARK: - R1: Circadian HRV Baseline Adjustment

    /// Circadian HRV baseline adjustment factor using a cosine model.
    /// Based on population-average diurnal HRV pattern: peak at ~04:00 (parasympathetic
    /// dominance during deep sleep), nadir at ~15:00 (sympathetic peak).
    /// Reference: Boudreau et al., PMC 2022; Hernando et al., Sensors 2018
    ///
    /// Uses a shifted cosine: factor = 1.0 + amplitude * cos(2π * (hour - peakHour) / 24)
    /// This produces a smooth continuous curve instead of stepped blocks, eliminating
    /// artificial discontinuities at hour boundaries.
    ///
    /// amplitude = 0.15 gives a range of 0.85 (nadir) to 1.15 (peak), matching
    /// the ~15% diurnal variation reported in the literature.
    static func circadianHRVFactor(for hour: Int) -> Double {
        let peakHour = 4.0     // HRV peak at ~04:00 during deep sleep
        let amplitude = 0.15   // ±15% variation from baseline
        let hourFraction = Double(hour)
        return 1.0 + amplitude * cos(2.0 * .pi * (hourFraction - peakHour) / 24.0)
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
        // Normalized relative to personal baseline (not fixed /20.0) so that users
        // with baseline HRV of 100ms and 30ms have proportionally equivalent signals.
        // A 40% deviation from personal baseline = full-strength trend signal.
        // (Appelhans & Luecken, Psychophysiology 2006)
        let hrvTrendComponent: Double = {
            guard let currentHRV = biometric?.hrv, currentHRV > 0 else { return 0.0 }
            let baseline = personalBaseline.currentBaseline
            guard baseline > 0 else { return 0.0 }
            let normalizedTrend = (currentHRV - baseline) / (baseline * 0.4)
            return Self.clamp(normalizedTrend * 0.10, -0.15, 0.15)
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
    /// Uses actual timestamps from the HR sample buffer instead of assuming
    /// a fixed 2-minute window. With 4 samples at 30s intervals, the actual
    /// span is ~90 seconds (1.5 min), not 2.0 min. Using real elapsed time
    /// corrects a 25% rate underestimation.
    ///
    /// - Parameters:
    ///   - currentHR: Current heart rate in BPM
    ///   - previousSample: Oldest HR sample with its timestamp
    ///   - currentTimestamp: Current sample timestamp
    /// - Returns: Rate of HR change in BPM per minute (positive = accelerating)
    static func calculateHRAcceleration(
        currentHR: Double,
        previousSample: (timestamp: Date, hr: Double)?
    ) -> Double {
        guard let previous = previousSample else { return 0.0 }
        let elapsedMinutes = Date().timeIntervalSince(previous.timestamp) / 60.0
        guard elapsedMinutes > 0.1 else { return 0.0 }  // Guard against near-zero division
        return (currentHR - previous.hr) / elapsedMinutes
    }

    /// Legacy overload for backward compatibility.
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
