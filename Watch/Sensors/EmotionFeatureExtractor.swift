//
//  EmotionFeatureExtractor.swift
//  Resonance Watch
//
//  30-second sliding window feature extraction for emotion detection.
//  Combines heart rate, HRV, and motion data into composite features
//  used by WatchEmotionClassifier.
//

import Foundation

// MARK: - Extracted Features

/// All features needed by the fuzzy emotion classifier.
struct EmotionFeatures {
    // Core biometric
    let arousal: Double           // 0-1, from HR reserve
    let stress: Double            // 0-1, from HRV ratio
    let valence: Double           // 0-1, mood estimate
    let energy: Double            // 0-1, energy estimate
    let focus: Double             // 0-1, focus estimate

    // Rate-of-change
    let hrAccelerationRate: Double   // positive = HR rising fast
    let hrvDepressionRate: Double    // positive = HRV dropping fast

    // Composite
    let sympatheticActivation: Double // hrAccelRate + hrvDepression + moveVar
    let motorCalm: Double             // inverse of movement variability

    // Motion
    let movementMagnitude: Double
    let movementVariability: Double
    let movementEntropy: Double
    let gestureFrequency: Double

    // Quality
    let sourceCount: Int
    let qualityAverage: Double
}

// MARK: - EmotionFeatureExtractor

final class EmotionFeatureExtractor {

    // MARK: - Configuration

    /// Sliding window for rate-of-change calculations.
    private static let windowSize = 6  // 6 samples at 5s intervals = 30s

    // MARK: - Circular Buffers

    private var hrBuffer: [Double] = []
    private var hrvBuffer: [Double] = []
    private var timestampBuffer: [Date] = []

    // MARK: - Feature Extraction

    /// Extracts features from current sensor readings and buffered history.
    func extractFeatures(
        heartRate: Double?,
        hrv: Double?,
        restingHeartRate: Double,
        hrvBaseline: Double,
        motionFeatures: MotionFeatures?,
        isStationary: Bool,
        isInWorkout: Bool
    ) -> EmotionFeatures {
        // Update circular buffers
        let now = Date()
        if let hr = heartRate {
            appendToBuffer(&hrBuffer, value: hr)
            appendToBuffer(&timestampBuffer, value: now)
        }
        if let h = hrv {
            appendToBuffer(&hrvBuffer, value: h)
        }

        // Arousal from HR reserve
        let arousal: Double
        if let hr = heartRate, hr > 0 {
            let maxHR = 220.0 - Double(StateEngineConstants.defaultUserAge)
            let reserve = maxHR - restingHeartRate
            arousal = reserve > 0 ? clamp((hr - restingHeartRate) / reserve, 0.0, 1.0) : 0.5
        } else {
            arousal = 0.5
        }

        // Stress from HRV
        let stress: Double
        if let h = hrv, h > 0 {
            let ratio = h / hrvBaseline
            stress = clamp(1.0 - (ratio * 0.6), 0.0, 1.0)
        } else {
            stress = 0.5
        }

        // Basic valence and energy
        let valence = clamp(0.5 - (stress * 0.3), 0.0, 1.0)
        let energy = (arousal * 0.6) + ((1.0 - stress) * 0.4)
        let focus = clamp(0.5 - (stress * 0.2), 0.0, 1.0)

        // Rate-of-change: HR acceleration
        let hrAccelerationRate = computeRateOfChange(hrBuffer)

        // Rate-of-change: HRV depression (positive = HRV dropping)
        let hrvDepressionRate = -computeRateOfChange(hrvBuffer)

        // Motion features
        let moveMag = motionFeatures?.movementMagnitude ?? 0.0
        let moveVar = motionFeatures?.movementVariability ?? 0.0
        let moveEntropy = motionFeatures?.movementEntropy ?? 0.0
        let gestureFreq = motionFeatures?.gestureFrequency ?? 0.0

        // Composite: sympathetic activation
        let sympatheticActivation = clamp(
            normalize(hrAccelerationRate, 0.0, 5.0) +
            normalize(hrvDepressionRate, 0.0, 10.0) +
            normalize(moveVar, 0.0, 0.5),
            0.0, 1.0
        )

        // Motor calm: inverse of movement variability
        let motorCalm = clamp(1.0 - normalize(moveVar, 0.0, 0.5), 0.0, 1.0)

        // Source count and quality
        var sourceCount = 0
        var qualitySum = 0.0
        if heartRate != nil {
            sourceCount += 1
            qualitySum += isStationary ? 1.0 : 0.7
        }
        if hrv != nil {
            sourceCount += 1
            qualitySum += isStationary ? 1.0 : 0.6
        }
        if motionFeatures != nil {
            sourceCount += 1
            qualitySum += 0.9
        }
        let qualityAverage = sourceCount > 0 ? qualitySum / Double(sourceCount) : 0.0

        return EmotionFeatures(
            arousal: arousal,
            stress: stress,
            valence: valence,
            energy: energy,
            focus: focus,
            hrAccelerationRate: hrAccelerationRate,
            hrvDepressionRate: hrvDepressionRate,
            sympatheticActivation: sympatheticActivation,
            motorCalm: motorCalm,
            movementMagnitude: moveMag,
            movementVariability: moveVar,
            movementEntropy: moveEntropy,
            gestureFrequency: gestureFreq,
            sourceCount: sourceCount,
            qualityAverage: qualityAverage
        )
    }

    /// Resets all internal buffers.
    func reset() {
        hrBuffer.removeAll()
        hrvBuffer.removeAll()
        timestampBuffer.removeAll()
    }

    // MARK: - Private Helpers

    /// Appends a value to a circular buffer, evicting oldest if at capacity.
    private func appendToBuffer<T>(_ buffer: inout [T], value: T) {
        buffer.append(value)
        if buffer.count > Self.windowSize {
            buffer.removeFirst()
        }
    }

    /// Computes the rate of change (slope) over the buffer using linear regression.
    private func computeRateOfChange(_ buffer: [Double]) -> Double {
        guard buffer.count >= 2 else { return 0.0 }

        let n = Double(buffer.count)
        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumX2 = 0.0

        for (i, value) in buffer.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += value
            sumXY += x * value
            sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return 0.0 }

        return (n * sumXY - sumX * sumY) / denominator
    }

    /// Normalizes a value to 0-1 range.
    private func normalize(_ value: Double, _ minVal: Double, _ maxVal: Double) -> Double {
        guard maxVal > minVal else { return 0.0 }
        return clamp((value - minVal) / (maxVal - minVal), 0.0, 1.0)
    }

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}
