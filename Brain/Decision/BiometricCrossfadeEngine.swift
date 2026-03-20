//
//  BiometricCrossfadeEngine.swift
//  Resonance
//
//  Adapts crossfade duration between tracks based on the user's real-time
//  heart rate and HRV. Uses the Karvonen heart rate reserve method for
//  zone classification and HRV ratio for stress detection.
//

#if os(iOS)

import Foundation

// MARK: - Biometric Crossfade Zone

/// Classifies the user's current physiological state for crossfade adaptation.
enum BiometricCrossfadeZone: String, Sendable, CaseIterable {
    case resting          // HR well below baseline -> 7.0s
    case lowNormal        // HR slightly below baseline -> 6.0s
    case normal           // HR near baseline -> 4.5s
    case elevated         // HR above baseline (workout) -> 2.5s
    case high             // Peak workout -> 1.5s
    case stressResponse   // HRV dip detected -> 3.0s
    case unknown          // Insufficient data -> user default
}

// MARK: - Crossfade Parameters

/// The computed crossfade configuration for a track transition.
struct CrossfadeParameters: Sendable {
    /// Crossfade duration in seconds (1.0 - 8.0).
    let duration: TimeInterval

    /// Confidence in the biometric-derived duration (0.0 - 1.0).
    let confidence: Double

    /// Human-readable explanation of the crossfade choice.
    let reason: String

    /// The physiological zone that determined the duration.
    let zone: BiometricCrossfadeZone

    static let `default` = CrossfadeParameters(
        duration: BiometricCrossfadeConstants.Durations.normal,
        confidence: 0.0,
        reason: "Default crossfade (no biometric data)",
        zone: .unknown
    )
}

// MARK: - Biometric Crossfade Engine

/// Computes adaptive crossfade durations from real-time biometric signals.
/// Uses the Karvonen heart rate reserve method for HR zone classification
/// and HRV-to-baseline ratio for stress detection.
final class BiometricCrossfadeEngine {

    // MARK: - Smoothing State

    /// Lock protecting mutable smoothing state.
    private let lock = NSLock()

    /// Previous crossfade duration for exponential smoothing.
    private var _previousDuration: TimeInterval?

    /// Smoothing factor (0.0 = full history, 1.0 = no smoothing).
    /// 0.7 gives a responsive-yet-stable feel.
    private let smoothingAlpha = 0.7

    // MARK: - Main Computation

    /// Computes crossfade parameters from the current biometric signal.
    ///
    /// - Parameters:
    ///   - biometric: The latest biometric reading from Apple Watch (nil if unavailable).
    ///   - restingHeartRate: User's resting HR from HealthKit (nil uses default).
    ///   - maxHeartRate: User's estimated max HR (nil uses 220 - defaultAge).
    ///   - personalHRVBaseline: The user's personal HRV baseline in ms.
    ///   - stateVector: Current state for context awareness.
    ///   - defaultDuration: Fallback duration from user preferences.
    /// - Returns: Computed crossfade parameters with duration, confidence, and zone.
    func computeCrossfadeParameters(
        biometric: BiometricSignal?,
        restingHeartRate: Double?,
        maxHeartRate: Double?,
        personalHRVBaseline: Double,
        stateVector: StateVector,
        defaultDuration: TimeInterval
    ) -> CrossfadeParameters {
        // 1. No biometric data -> unknown zone with user default
        guard let bio = biometric, let hr = bio.heartRate else {
            return fallback(defaultDuration)
        }

        // 2. Irregular rhythm detected -> safety fallback
        if bio.hasRecentIrregularRhythm {
            return fallback(defaultDuration)
        }

        // 3. HR zone classification using Karvonen heart rate reserve method
        let resting = restingHeartRate ?? StateEngineConstants.defaultRestingHeartRate
        let defaultAge = Double(StateEngineConstants.defaultUserAge)
        let maxHR = maxHeartRate ?? (StateEngineConstants.maxHeartRateBase - defaultAge)
        let hrReserve = maxHR - resting
        guard hrReserve > 0 else { return fallback(defaultDuration) }

        let normalizedHR = min(max((hr - resting) / hrReserve, 0.0), 1.0)

        var zone: BiometricCrossfadeZone
        var duration: TimeInterval

        if normalizedHR < BiometricCrossfadeConstants.Thresholds.restingCeiling {
            zone = .resting
            duration = BiometricCrossfadeConstants.Durations.resting
        } else if normalizedHR < BiometricCrossfadeConstants.Thresholds.lowNormalCeiling {
            zone = .lowNormal
            duration = BiometricCrossfadeConstants.Durations.lowNormal
        } else if normalizedHR < BiometricCrossfadeConstants.Thresholds.normalCeiling {
            zone = .normal
            duration = BiometricCrossfadeConstants.Durations.normal
        } else if normalizedHR < BiometricCrossfadeConstants.Thresholds.elevatedCeiling {
            zone = .elevated
            duration = BiometricCrossfadeConstants.Durations.elevated
        } else {
            zone = .high
            duration = BiometricCrossfadeConstants.Durations.high
        }

        // 4. HRV stress override (only when quality is sufficient)
        if let hrv = bio.hrv,
           bio.hrvQuality > BiometricCrossfadeConstants.Thresholds.hrvQualityMinimum,
           personalHRVBaseline > 0 {
            let hrvRatio = hrv / personalHRVBaseline
            if hrvRatio < BiometricCrossfadeConstants.Thresholds.deepStressHRVRatio {
                zone = .stressResponse
                duration = BiometricCrossfadeConstants.Durations.deepStressBridge
            } else if hrvRatio < BiometricCrossfadeConstants.Thresholds.stressHRVRatio {
                zone = .stressResponse
                duration = BiometricCrossfadeConstants.Durations.stressBridge
            }
        }

        // 5. Confidence based on sample quality
        let sampleQuality = bio.sampleQuality
        var confidence: Double
        if sampleQuality < BiometricCrossfadeConstants.Thresholds.minimumSampleQuality {
            // Blend toward default when quality is low
            duration = (duration * sampleQuality) + (defaultDuration * (1.0 - sampleQuality))
            confidence = sampleQuality
        } else {
            confidence = min(sampleQuality, 1.0)
        }

        // 6. Exponential smoothing (stress override bypasses smoothing)
        if zone != .stressResponse {
            lock.lock()
            let prev = _previousDuration
            lock.unlock()
            if let prev = prev {
                duration = prev * (1.0 - smoothingAlpha) + duration * smoothingAlpha
            }
        }

        // 7. Clamp to valid range
        duration = min(
            max(duration, BiometricCrossfadeConstants.Durations.minimum),
            BiometricCrossfadeConstants.Durations.maximum
        )

        // Store for next smoothing pass
        lock.lock()
        _previousDuration = duration
        lock.unlock()

        let reason = describeZone(zone, hr: hr, hrv: bio.hrv, duration: duration)
        return CrossfadeParameters(
            duration: duration,
            confidence: confidence,
            reason: reason,
            zone: zone
        )
    }

    // MARK: - Reset

    /// Resets smoothing state (e.g., on session change).
    func reset() {
        lock.lock()
        _previousDuration = nil
        lock.unlock()
    }

    // MARK: - Private Helpers

    private func fallback(_ defaultDuration: TimeInterval) -> CrossfadeParameters {
        CrossfadeParameters(
            duration: defaultDuration,
            confidence: 0.0,
            reason: "Default crossfade",
            zone: .unknown
        )
    }

    private func describeZone(
        _ zone: BiometricCrossfadeZone,
        hr: Double,
        hrv: Double?,
        duration: TimeInterval
    ) -> String {
        switch zone {
        case .resting:
            return String(format: "Resting HR (%.0f BPM) — %.1fs meditative blend", hr, duration)
        case .lowNormal:
            return String(format: "Calm HR (%.0f BPM) — %.1fs extended blend", hr, duration)
        case .normal:
            return String(format: "Normal HR (%.0f BPM) — %.1fs standard crossfade", hr, duration)
        case .elevated:
            return String(format: "Elevated HR (%.0f BPM) — %.1fs quick transition", hr, duration)
        case .high:
            return String(format: "Peak HR (%.0f BPM) — %.1fs punchy cut", hr, duration)
        case .stressResponse:
            return String(format: "Stress detected (HRV: %.0f ms) — %.1fs breathing bridge", hrv ?? 0, duration)
        case .unknown:
            return String(format: "%.1fs default crossfade", duration)
        }
    }
}

#endif
