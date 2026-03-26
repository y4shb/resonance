//
//  EmotionMotionSensor.swift
//  Resonance Watch
//
//  CMMotionManager wrapper with adaptive sampling for emotion detection.
//  Computes per-window motion features: magnitude, variability, entropy,
//  rotation magnitude, and gesture frequency.
//  Battery-aware: adapts sampling rate and stops in background.
//

import CoreMotion
import Foundation
import Combine

// MARK: - Motion Features

/// Computed motion features over a time window.
struct MotionFeatures: Sendable {
    /// RMS of accelerometer user acceleration magnitude (g).
    let movementMagnitude: Double
    /// Standard deviation of acceleration magnitude over the window.
    let movementVariability: Double
    /// Shannon entropy of acceleration magnitude (binned).
    let movementEntropy: Double
    /// RMS of gyroscope rotation rate (rad/s).
    let rotationMagnitude: Double
    /// Number of acceleration peaks above threshold per second.
    let gestureFrequency: Double
    /// Timestamp when features were computed.
    let timestamp: Date
}

// MARK: - EmotionMotionSensor

final class EmotionMotionSensor: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var latestFeatures: MotionFeatures?
    @Published private(set) var isActive = false

    // MARK: - Configuration

    /// Sampling rates (Hz) for each activity level.
    private enum SamplingRate {
        static let stationary: TimeInterval = 1.0 / 2.0   // 2 Hz
        static let walking: TimeInterval    = 1.0 / 5.0   // 5 Hz
        static let workout: TimeInterval    = 1.0 / 10.0  // 10 Hz
    }

    /// Window duration for feature computation.
    private static let windowDuration: TimeInterval = 5.0

    /// Peak detection threshold (g) for gesture frequency.
    private static let peakThreshold: Double = 0.3

    /// Number of bins for entropy calculation.
    private static let entropyBins = 10

    // MARK: - Private Properties

    private let motionManager: CMMotionManager
    private var accelerationBuffer: [(magnitude: Double, timestamp: TimeInterval)] = []
    private var rotationBuffer: [(magnitude: Double, timestamp: TimeInterval)] = []
    private var computeTimer: Timer?
    private var currentSamplingInterval: TimeInterval = SamplingRate.stationary

    // MARK: - Initialization

    /// Initializes with a shared CMMotionManager instance.
    /// Important: Only one CMMotionManager should exist per app.
    init(motionManager: CMMotionManager = CMMotionManager()) {
        self.motionManager = motionManager
    }

    // MARK: - Monitoring Control

    /// Starts device motion updates with the current sampling rate.
    func startMonitoring(isStationary: Bool = true, isInWorkout: Bool = false) {
        guard motionManager.isDeviceMotionAvailable else {
            logWarning("Device motion not available", category: .general)
            return
        }

        guard !isActive else {
            updateSamplingRate(isStationary: isStationary, isInWorkout: isInWorkout)
            return
        }

        isActive = true
        updateSamplingRate(isStationary: isStationary, isInWorkout: isInWorkout)
        startDeviceMotionUpdates()
        startComputeTimer()
        logInfo("EmotionMotionSensor started", category: .general)
    }

    /// Stops device motion updates and clears buffers.
    func stopMonitoring() {
        guard isActive else { return }
        isActive = false
        motionManager.stopDeviceMotionUpdates()
        computeTimer?.invalidate()
        computeTimer = nil
        accelerationBuffer.removeAll()
        rotationBuffer.removeAll()
        logInfo("EmotionMotionSensor stopped", category: .general)
    }

    /// Updates the sampling rate based on current activity state.
    func updateSamplingRate(isStationary: Bool, isInWorkout: Bool) {
        let newInterval: TimeInterval
        if isInWorkout {
            newInterval = SamplingRate.workout
        } else if isStationary {
            newInterval = SamplingRate.stationary
        } else {
            newInterval = SamplingRate.walking
        }

        guard newInterval != currentSamplingInterval else { return }
        currentSamplingInterval = newInterval
        motionManager.deviceMotionUpdateInterval = newInterval

        logDebug(
            "Motion sampling rate updated: \(1.0 / newInterval) Hz",
            category: .general
        )
    }

    // MARK: - Private: Motion Updates

    private func startDeviceMotionUpdates() {
        motionManager.deviceMotionUpdateInterval = currentSamplingInterval
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    logError("Device motion error", error: error, category: .general)
                }
                return
            }
            self.processMotionSample(motion)
        }
    }

    private func processMotionSample(_ motion: CMDeviceMotion) {
        let accel = motion.userAcceleration
        let accelMag = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)

        let rotation = motion.rotationRate
        let rotMag = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)

        let now = ProcessInfo.processInfo.systemUptime
        accelerationBuffer.append((magnitude: accelMag, timestamp: now))
        rotationBuffer.append((magnitude: rotMag, timestamp: now))

        // Trim to window duration
        let cutoff = now - Self.windowDuration
        accelerationBuffer.removeAll { $0.timestamp < cutoff }
        rotationBuffer.removeAll { $0.timestamp < cutoff }
    }

    // MARK: - Private: Feature Computation

    private func startComputeTimer() {
        computeTimer = Timer.scheduledTimer(
            withTimeInterval: Self.windowDuration,
            repeats: true
        ) { [weak self] _ in
            self?.computeFeatures()
        }
        computeTimer?.tolerance = 0.5
    }

    private func computeFeatures() {
        guard !accelerationBuffer.isEmpty else { return }

        let accelValues = accelerationBuffer.map { $0.magnitude }
        let rotValues = rotationBuffer.map { $0.magnitude }

        let movementMagnitude = rms(accelValues)
        let movementVariability = standardDeviation(accelValues)
        let movementEntropy = shannonEntropy(accelValues, bins: Self.entropyBins)
        let rotationMagnitude = rms(rotValues)
        let gestureFrequency = computeGestureFrequency(
            accelValues,
            threshold: Self.peakThreshold,
            windowDuration: Self.windowDuration
        )

        let features = MotionFeatures(
            movementMagnitude: movementMagnitude,
            movementVariability: movementVariability,
            movementEntropy: movementEntropy,
            rotationMagnitude: rotationMagnitude,
            gestureFrequency: gestureFrequency,
            timestamp: Date()
        )

        latestFeatures = features

        logDebug(
            "Motion features: mag=\(String(format: "%.3f", movementMagnitude)), "
            + "var=\(String(format: "%.3f", movementVariability)), "
            + "entropy=\(String(format: "%.3f", movementEntropy))",
            category: .general
        )
    }

    // MARK: - Math Helpers

    private func rms(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sumSquares = values.reduce(0.0) { $0 + $1 * $1 }
        return sqrt(sumSquares / Double(values.count))
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        let mean = values.reduce(0.0, +) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
        return sqrt(variance)
    }

    private func shannonEntropy(_ values: [Double], bins: Int) -> Double {
        guard !values.isEmpty, bins > 0 else { return 0.0 }
        let minVal = values.min() ?? 0.0
        let maxVal = values.max() ?? 1.0
        let range = maxVal - minVal
        guard range > 0 else { return 0.0 }

        var histogram = [Int](repeating: 0, count: bins)
        for value in values {
            let bin = min(bins - 1, Int((value - minVal) / range * Double(bins)))
            histogram[bin] += 1
        }

        let total = Double(values.count)
        var entropy = 0.0
        for count in histogram where count > 0 {
            let p = Double(count) / total
            entropy -= p * log2(p)
        }
        return entropy
    }

    private func computeGestureFrequency(
        _ values: [Double],
        threshold: Double,
        windowDuration: TimeInterval
    ) -> Double {
        guard windowDuration > 0 else { return 0.0 }
        let peakCount = values.filter { $0 > threshold }.count
        return Double(peakCount) / windowDuration
    }
}
