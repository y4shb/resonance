//
//  SensorConfidenceScorer.swift
//  Resonance
//
//  Workstream 2.4: Sensor confidence scoring for HRV measurements.
//
//  Evaluates the quality of HRV samples based on:
//    1. Motion context: Samples recorded during motion are lower quality.
//    2. R-R interval consistency: High coefficient of variation (CV > 0.25)
//       indicates noisy or unreliable readings.
//
//  The resulting hrvQuality score (0.0 - 1.0) is stored on BiometricSignal
//  and used to gate HRV credit in the reward function: if hrvQuality < 0.8,
//  the HRV component is discounted by the quality factor.
//

#if os(iOS)

import Foundation
import HealthKit

// MARK: - Sensor Confidence Constants

enum SensorConfidenceConstants {
    /// R-R interval CV threshold above which HRV is flagged as low quality.
    static let rrCVThreshold: Double = 0.25

    /// Minimum HRV quality below which the HRV signal should be heavily discounted.
    static let minimumUsableQuality: Double = 0.3

    /// Quality floor for stationary readings (always at least this quality).
    static let stationaryFloor: Double = 0.85

    /// Quality penalty for motion-context recordings.
    static let motionPenalty: Double = 0.3

    /// Quality penalty for high R-R variability.
    static let highCVPenalty: Double = 0.35

    /// Quality penalty for workout context.
    static let workoutPenalty: Double = 0.5

    /// Threshold for hrvQuality below which HRV credit is discounted.
    static let discountThreshold: Double = 0.8
}

// MARK: - Sensor Confidence Scorer

/// Evaluates the reliability of HRV sensor readings.
///
/// Uses two independent quality signals:
/// 1. **Motion context**: Readings during physical movement are noisier.
///    HealthKit's `HKMetadataKeyHeartRateMotionContext` distinguishes
///    sedentary from active readings.
/// 2. **R-R interval consistency**: The coefficient of variation of
///    inter-beat intervals. High CV (> 0.25) suggests arrhythmia,
///    sensor contact issues, or motion artifact.
struct SensorConfidenceScorer {

    /// Computes an overall HRV quality score from available signals.
    ///
    /// - Parameters:
    ///   - isStationary: Whether the user was stationary during measurement.
    ///   - isInWorkout: Whether the user was in an active workout.
    ///   - motionContext: HealthKit motion context value (1 = sedentary, 2 = active).
    ///     Nil if metadata was not available on the sample.
    ///   - rrIntervalCV: Coefficient of variation of R-R intervals.
    ///     Nil if R-R data was not available.
    ///   - accelerometerMagnitude: Current accelerometer magnitude (0.0 - 1.0+).
    /// - Returns: Quality score in [0.0, 1.0] where 1.0 = highest confidence.
    static func computeHRVQuality(
        isStationary: Bool,
        isInWorkout: Bool,
        motionContext: Int? = nil,
        rrIntervalCV: Double? = nil,
        accelerometerMagnitude: Double = 0.0
    ) -> Double {
        var quality = 1.0

        // 1. Motion context penalty
        if isInWorkout {
            quality -= SensorConfidenceConstants.workoutPenalty
        } else if !isStationary {
            quality -= SensorConfidenceConstants.motionPenalty
        }

        // HealthKit motion context metadata (if available)
        // HKHeartRateMotionContext: 1 = sedentary, 2 = active
        // Penalize active context — motion artifacts corrupt HRV readings
        if let context = motionContext, context == 2 {
            quality -= SensorConfidenceConstants.motionPenalty * 0.5
        }

        // Accelerometer-based motion penalty (continuous scale)
        if accelerometerMagnitude > 0.3 {
            let motionPenalty = min(0.4, accelerometerMagnitude * 0.3)
            quality -= motionPenalty
        }

        // 2. R-R interval consistency check
        if let cv = rrIntervalCV {
            if cv > SensorConfidenceConstants.rrCVThreshold {
                // CV is too high -- R-R intervals are inconsistent
                let excessCV = cv - SensorConfidenceConstants.rrCVThreshold
                let cvPenalty = min(
                    SensorConfidenceConstants.highCVPenalty,
                    excessCV * 1.5
                )
                quality -= cvPenalty
            }
        }

        // Stationary floor: if the user is confirmed stationary and not in a workout,
        // quality should never drop below the floor.
        if isStationary && !isInWorkout {
            quality = max(quality, SensorConfidenceConstants.stationaryFloor)
        }

        return max(SensorConfidenceConstants.minimumUsableQuality, min(1.0, quality))
    }

    /// Computes the coefficient of variation of R-R intervals.
    ///
    /// - Parameter rrIntervals: Array of R-R interval durations in milliseconds.
    /// - Returns: CV (standard deviation / mean), or nil if insufficient data.
    static func computeRRIntervalCV(rrIntervals: [Double]) -> Double? {
        guard rrIntervals.count >= 3 else { return nil }

        let mean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        guard mean > 0 else { return nil }

        let variance = rrIntervals.reduce(0.0) { sum, rr in
            let diff = rr - mean
            return sum + diff * diff
        } / Double(rrIntervals.count)

        let stdDev = sqrt(variance)
        return stdDev / mean
    }

    /// Applies the HRV quality discount to a reward credit value.
    ///
    /// If hrvQuality >= 0.8, the credit is returned unchanged.
    /// If hrvQuality < 0.8, the credit is multiplied by the quality factor,
    /// reducing the influence of unreliable HRV readings.
    ///
    /// - Parameters:
    ///   - credit: The raw HRV-derived credit/reward value.
    ///   - hrvQuality: The quality score (0.0 - 1.0).
    /// - Returns: The discounted credit value.
    static func applyQualityDiscount(credit: Double, hrvQuality: Double) -> Double {
        guard hrvQuality < SensorConfidenceConstants.discountThreshold else {
            return credit
        }
        return credit * hrvQuality
    }
}

#endif
