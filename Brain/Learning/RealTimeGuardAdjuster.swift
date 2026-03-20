//
//  RealTimeGuardAdjuster.swift
//  Resonance
//
//  Monitors real-time playback conditions and produces adjustments for the next song selection.
//  Feeds into DecisionEngine's guard system to modify scoring weights dynamically.
//  Implements Phase 8 (Learning Loop) guard rules:
//    1. Rising HR during calm need -> reduce target BPM for next song
//    2. Falling engagement (multiple skips) -> increase familiarity weighting
//

#if os(iOS)

import Foundation
import Combine

/// Monitors real-time playback conditions and produces adjustments for the next song selection.
/// Feeds into DecisionEngine's guard system to modify scoring weights dynamically.
@MainActor
final class RealTimeGuardAdjuster: ObservableObject {

    // MARK: - Published State

    /// Current active adjustments
    @Published private(set) var activeAdjustments: [GuardAdjustment] = []

    // MARK: - Adjustment Types

    struct GuardAdjustment: Identifiable {
        let id = UUID()
        let type: AdjustmentType
        let reason: String
        let magnitude: Double  // 0.0 to 1.0
        let createdAt: Date

        /// Whether this adjustment has expired (older than 10 minutes)
        var isExpired: Bool {
            Date().timeIntervalSince(createdAt) > 600
        }
    }

    enum AdjustmentType {
        case reduceBPM          // Lower BPM target for next song
        case increaseFamiliarity // Prefer more familiar songs
        case reduceEnergy       // Lower energy target
        case increaseCalm       // Prefer calmer songs
        case discountBiometrics // Reduce biometric signal weight due to motion
    }

    // MARK: - Tracking State

    private var recentSkipCount = 0
    private var recentSkipWindow: [Date] = []
    private var lastHeartRate: Double?
    private var heartRateBaseline: Double?
    private var heartRateTrend: [Double] = []  // Last N HR readings

    // MARK: - Constants

    /// Number of skips in 5 minutes to trigger familiarity boost
    private let skipThreshold = 3
    /// HR increase above baseline to trigger BPM reduction
    private let hrRiseThreshold = 15.0
    /// Maximum number of HR readings to keep in trend
    private let maxTrendSize = 10
    /// Skip window in seconds (5 minutes)
    private let skipWindowSeconds: TimeInterval = 300

    // MARK: - Event Processing

    /// Record a skip event for engagement tracking.
    func recordSkip() {
        let now = Date()
        recentSkipWindow.append(now)

        // Prune old entries outside the window
        recentSkipWindow = recentSkipWindow.filter {
            now.timeIntervalSince($0) < skipWindowSeconds
        }

        recentSkipCount = recentSkipWindow.count

        // Check if skip rate triggers adjustment
        if recentSkipCount >= skipThreshold {
            addAdjustment(
                type: .increaseFamiliarity,
                reason: "\(recentSkipCount) skips in \(Int(skipWindowSeconds/60)) min — preferring familiar songs",
                magnitude: min(1.0, Double(recentSkipCount) / Double(skipThreshold + 2))
            )
            logInfo("Guard: familiarity boost triggered (\(recentSkipCount) recent skips)", category: .decisionEngine)
        }
    }

    /// Record a heart rate reading for trend monitoring.
    /// - Parameters:
    ///   - heartRate: Current heart rate
    ///   - currentNeed: The current music need from StateEngine
    func recordHeartRate(_ heartRate: Double, currentNeed: MusicNeed?) {
        // Initialize or update baseline via EMA (alpha=0.1 for slow adaptation)
        if let baseline = heartRateBaseline {
            heartRateBaseline = baseline * 0.9 + heartRate * 0.1
        } else {
            heartRateBaseline = heartRate
        }

        // Track trend
        heartRateTrend.append(heartRate)
        if heartRateTrend.count > maxTrendSize {
            heartRateTrend.removeFirst()
        }

        lastHeartRate = heartRate

        // Check for rising HR during calm/focus need
        guard let baseline = heartRateBaseline,
              let need = currentNeed,
              (need == .calm || need == .focus) else { return }

        let hrRise = heartRate - baseline
        if hrRise > hrRiseThreshold {
            addAdjustment(
                type: .reduceBPM,
                reason: "HR rising (+\(Int(hrRise)) BPM) during \(need) need — lowering target BPM",
                magnitude: min(1.0, hrRise / (hrRiseThreshold * 2))
            )

            // Also suggest calmer songs
            addAdjustment(
                type: .increaseCalm,
                reason: "Elevated HR during \(need) need — preferring calmer songs",
                magnitude: min(1.0, hrRise / (hrRiseThreshold * 2))
            )

            logInfo("Guard: BPM reduction triggered (HR +\(Int(hrRise)) during \(need))", category: .decisionEngine)
        }
    }

    // MARK: - Motion-Aware Reward Gating (Workstream 2.2)

    /// Current motion intensity level (0.0 = stationary, 1.0 = vigorous).
    /// Updated from accelerometer data via BiometricSignal.accelerometerMagnitude.
    private(set) var motionIntensity = 0.0

    /// Records the current motion intensity from accelerometer data.
    /// When motionIntensity > 0.5, biometric credit weights (HRV/HR) should be
    /// reduced by a factor of (1.0 - motionIntensity) to avoid noise from physical
    /// movement contaminating the reward signal.
    ///
    /// - Parameter intensity: Accelerometer magnitude normalized to 0.0 - 1.0.
    func recordMotionIntensity(_ intensity: Double) {
        let clamped = min(1.0, max(0.0, intensity))

        // EMA smoothing (alpha = 0.3 for responsive but stable tracking)
        motionIntensity = motionIntensity * 0.7 + clamped * 0.3

        if motionIntensity > 0.5 {
            addAdjustment(
                type: .discountBiometrics,
                reason: "High motion (\(String(format: "%.0f%%", motionIntensity * 100))) — reducing biometric weight",
                magnitude: motionIntensity
            )
            logInfo(
                "Guard: motion-aware gating active (intensity=\(String(format: "%.2f", motionIntensity)))",
                category: .decisionEngine
            )
        }
    }

    /// Returns the biometric discount factor based on current motion intensity.
    /// When motion > 0.5, returns (1.0 - motionIntensity); otherwise returns 1.0 (no discount).
    var biometricDiscountFactor: Double {
        motionIntensity > 0.5 ? (1.0 - motionIntensity) : 1.0
    }

    /// Record a non-skip (full listen) to decay skip tracking.
    func recordFullListen() {
        // Prune expired entries first
        let now = Date()
        recentSkipWindow = recentSkipWindow.filter {
            now.timeIntervalSince($0) < skipWindowSeconds
        }
        // Remove the oldest skip to reduce pressure on full listen
        if !recentSkipWindow.isEmpty {
            recentSkipWindow.removeFirst()
        }
        recentSkipCount = recentSkipWindow.count
    }

    /// Get BPM adjustment for the next song selection.
    /// Returns a negative value to reduce target BPM, or 0 for no adjustment.
    var bpmAdjustment: Double {
        let bpmAdjustments = activeAdjustments.filter { $0.type == .reduceBPM && !$0.isExpired }
        guard let strongest = bpmAdjustments.max(by: { $0.magnitude < $1.magnitude }) else { return 0.0 }
        return -strongest.magnitude * 30.0  // Up to -30 BPM reduction
    }

    /// Get familiarity weight boost for the next song selection.
    /// Returns a positive value to add to familiarity weight, or 0 for no adjustment.
    var familiarityBoost: Double {
        let famAdjustments = activeAdjustments.filter { $0.type == .increaseFamiliarity && !$0.isExpired }
        guard let strongest = famAdjustments.max(by: { $0.magnitude < $1.magnitude }) else { return 0.0 }
        return strongest.magnitude * 0.15  // Up to +0.15 familiarity weight boost
    }

    /// Whether any guard adjustments are currently active.
    var hasActiveAdjustments: Bool {
        activeAdjustments.contains(where: { !$0.isExpired })
    }

    /// Reset all tracking state (e.g., on session end).
    func reset() {
        activeAdjustments.removeAll()
        recentSkipCount = 0
        recentSkipWindow.removeAll()
        lastHeartRate = nil
        heartRateBaseline = nil
        heartRateTrend.removeAll()
        motionIntensity = 0.0
    }

    // MARK: - Private

    private func addAdjustment(type: AdjustmentType, reason: String, magnitude: Double) {
        // Remove existing adjustments of the same type (replace with new)
        activeAdjustments.removeAll { $0.type == type }
        // Prune expired
        activeAdjustments.removeAll { $0.isExpired }

        activeAdjustments.append(GuardAdjustment(
            type: type,
            reason: reason,
            magnitude: magnitude,
            createdAt: Date()
        ))
    }
}

#endif
