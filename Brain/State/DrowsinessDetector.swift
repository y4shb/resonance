//
//  DrowsinessDetector.swift
//  Resonance
//
//  Detects driver drowsiness from declining biometric signals and triggers
//  alerting music selection during CarPlay commute sessions.
//
//  Composite score: hrvDecline*0.35 + hrDecline*0.30 + motionReduction*0.35
//  All three must persist for 3+ minutes before activation.
//
//  Safety: NEVER display complex UI or alerts while driving.
//  Only response is to silently adjust music (higher tempo, louder).
//
//  Research: Lal & Craig 2002, Patel et al. 2019, Sahayadhas et al. 2012
//  Related: StateCalculationHelpers, PersonalBaseline, AnxietyDetector
//

#if os(iOS)

import Foundation

// MARK: - Drowsiness Constants

/// Named constants for the drowsiness detection subsystem.
enum DrowsinessConstants {

    // MARK: - Signal Weights (must sum to 1.0)

    /// Weight of HRV decline rate in composite score.
    static let hrvDeclineWeight: Double = 0.35

    /// Weight of HR decline rate in composite score.
    static let hrDeclineWeight: Double = 0.30

    /// Weight of motion reduction in composite score.
    static let motionReductionWeight: Double = 0.35

    // MARK: - Level Thresholds

    /// Composite score above which state is considered mild drowsiness.
    static let mildThreshold: Double = 0.4

    /// Composite score above which state is considered moderate drowsiness.
    static let moderateThreshold: Double = 0.6

    /// Composite score above which state is considered severe drowsiness.
    static let severeThreshold: Double = 0.8

    // MARK: - Temporal Requirements

    /// Minimum number of consecutive declining readings before the score is valid.
    /// At 30-second intervals, 6 readings = 3 minutes.
    static let requiredConsecutiveReadings: Int = 6

    /// Maximum age (seconds) of buffered readings to consider.
    /// Readings older than this are pruned.
    static let readingBufferWindowSeconds: TimeInterval = 300.0

    // MARK: - Signal Normalization

    /// HRV decline percentage (from personal baseline) that maps to a 1.0 signal.
    /// A 30% decline from baseline = maximum HRV decline signal.
    static let hrvDeclineNormalizationFraction: Double = 0.30

    /// HR decline (BPM below session average) that maps to a 1.0 signal.
    /// A 15 BPM decline from session average = maximum HR decline signal.
    static let hrDeclineNormalizationBPM: Double = 15.0

    /// Accelerometer magnitude below which the user is considered very still.
    static let motionStillThreshold: Double = 0.03

    /// Baseline motion magnitude for normalization (typical driving movement).
    static let baselineMotionMagnitude: Double = 0.15

    // MARK: - Buffer Sizes

    /// Maximum number of readings to retain in each signal buffer.
    static let maxBufferSize: Int = 12  // ~6 minutes at 30s intervals

    // MARK: - Music Response

    /// Minimum BPM boost when moderate drowsiness is detected.
    static let moderateBPMBoost: Double = 15.0

    /// Minimum BPM boost when severe drowsiness is detected.
    static let severeBPMBoost: Double = 25.0

    /// Minimum energy level target for alerting music (0-1).
    static let alertingEnergyFloor: Double = 0.6
}

// MARK: - Drowsiness Level

/// Severity classification for detected drowsiness state.
enum DrowsinessLevel: String, Codable, CaseIterable, Sendable {
    /// No drowsiness indicators detected.
    case alert

    /// Mild decline in biometrics; monitoring continues.
    case mildDrowsiness

    /// Clear drowsiness pattern; alerting music intervention activated.
    case moderateDrowsiness

    /// Severe drowsiness indicators; maximum alerting music intervention.
    case severeDrowsiness

    /// Numeric severity for comparison (0 = alert, 3 = severe).
    var severity: Int {
        switch self {
        case .alert: return 0
        case .mildDrowsiness: return 1
        case .moderateDrowsiness: return 2
        case .severeDrowsiness: return 3
        }
    }

    /// Human-readable description for logging.
    var displayName: String {
        switch self {
        case .alert: return "Alert"
        case .mildDrowsiness: return "Mild Drowsiness"
        case .moderateDrowsiness: return "Moderate Drowsiness"
        case .severeDrowsiness: return "Severe Drowsiness"
        }
    }

    /// Whether this level should trigger alerting music intervention.
    var shouldTriggerAlertingMusic: Bool {
        severity >= DrowsinessLevel.moderateDrowsiness.severity
    }

    /// The BPM boost to apply for this drowsiness level.
    var bpmBoost: Double {
        switch self {
        case .alert: return 0.0
        case .mildDrowsiness: return 0.0
        case .moderateDrowsiness: return DrowsinessConstants.moderateBPMBoost
        case .severeDrowsiness: return DrowsinessConstants.severeBPMBoost
        }
    }
}

// MARK: - Drowsiness Music Recommendation

/// Describes the music adjustments to make when drowsiness is detected.
/// Consumed by the DecisionEngine to modify song scoring.
struct DrowsinessMusicRecommendation: Sendable {
    /// The detected drowsiness level.
    let level: DrowsinessLevel

    /// BPM boost to apply to target BPM range.
    let bpmBoost: Double

    /// Minimum energy floor for song selection (0-1).
    let minimumEnergy: Double

    /// Whether to prefer tracks with higher loudness.
    let preferLouder: Bool

    /// Whether active music intervention is recommended.
    var isActive: Bool { level.shouldTriggerAlertingMusic }
}

// MARK: - Drowsiness Detector

/// Detects drowsiness from composite biometric signals during commute sessions.
/// Thread-safe via NSLock. Requires 3+ minutes of consistent decline before
/// activation. Produces DrowsinessMusicRecommendation for the DecisionEngine.
/// Safety: NEVER triggers UI elements -- only adjusts music.
final class DrowsinessDetector {

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - Dependencies

    private let personalBaseline: PersonalBaseline

    // MARK: - Current State

    private var _currentLevel: DrowsinessLevel = .alert
    private var _currentScore: Double = 0.0
    private var _consecutiveDecliningCount: Int = 0

    /// Thread-safe read of the current drowsiness level.
    var currentLevel: DrowsinessLevel {
        lock.lock(); defer { lock.unlock() }; return _currentLevel
    }

    /// Thread-safe read of the current composite score.
    var currentScore: Double {
        lock.lock(); defer { lock.unlock() }; return _currentScore
    }

    // MARK: - Signal Buffers

    /// Recent HRV readings for computing decline rate.
    private var hrvBuffer: [(timestamp: Date, value: Double)] = []

    /// Recent HR readings for computing decline rate.
    private var hrBuffer: [(timestamp: Date, value: Double)] = []

    /// Recent motion readings for computing reduction.
    private var motionBuffer: [(timestamp: Date, value: Double)] = []

    /// Session-average HR, used as reference for HR decline detection.
    private var sessionHRSum: Double = 0.0
    private var sessionHRCount: Int = 0

    // MARK: - Initialization

    init(personalBaseline: PersonalBaseline) {
        self.personalBaseline = personalBaseline

        logDebug("DrowsinessDetector initialized", category: .stateEngine)
    }

    // MARK: - Main Update

    /// Processes a new biometric reading and updates the drowsiness state.
    ///
    /// Called each StateEngine cycle (~30s) during commute sessions.
    /// Computes the composite drowsiness score from three declining signals,
    /// enforces the 3-minute temporal requirement, and updates the level.
    ///
    /// - Parameter biometric: Current biometric signal from Apple Watch.
    func processReading(biometric: BiometricSignal?) {
        lock.lock()

        let now = Date()

        // Prune old readings from buffers
        pruneBuffer(&hrvBuffer, before: now.addingTimeInterval(-DrowsinessConstants.readingBufferWindowSeconds))
        pruneBuffer(&hrBuffer, before: now.addingTimeInterval(-DrowsinessConstants.readingBufferWindowSeconds))
        pruneBuffer(&motionBuffer, before: now.addingTimeInterval(-DrowsinessConstants.readingBufferWindowSeconds))

        // Buffer new readings
        if let hrv = biometric?.hrv, hrv > 0 {
            hrvBuffer.append((timestamp: now, value: hrv))
            if hrvBuffer.count > DrowsinessConstants.maxBufferSize {
                hrvBuffer.removeFirst()
            }
        }

        if let hr = biometric?.heartRate, hr > 0 {
            hrBuffer.append((timestamp: now, value: hr))
            if hrBuffer.count > DrowsinessConstants.maxBufferSize {
                hrBuffer.removeFirst()
            }
            // Update session average
            sessionHRSum += hr
            sessionHRCount += 1
        }

        let motionMagnitude = biometric?.accelerometerMagnitude ?? 0.0
        motionBuffer.append((timestamp: now, value: motionMagnitude))
        if motionBuffer.count > DrowsinessConstants.maxBufferSize {
            motionBuffer.removeFirst()
        }

        // 1. Compute individual signal components (each 0-1)
        let hrvSignal = computeHRVDeclineSignal()
        let hrSignal = computeHRDeclineSignal()
        let motionSignal = computeMotionReductionSignal()

        // 2. Check temporal requirement: all three signals must show decline
        let allDeclining = hrvSignal > 0.1 && hrSignal > 0.1 && motionSignal > 0.1
        if allDeclining {
            _consecutiveDecliningCount += 1
        } else {
            _consecutiveDecliningCount = max(0, _consecutiveDecliningCount - 1)
        }

        // 3. Composite score (only activated after temporal requirement met)
        let rawScore: Double
        if _consecutiveDecliningCount >= DrowsinessConstants.requiredConsecutiveReadings {
            rawScore = hrvSignal * DrowsinessConstants.hrvDeclineWeight
                + hrSignal * DrowsinessConstants.hrDeclineWeight
                + motionSignal * DrowsinessConstants.motionReductionWeight
        } else {
            // Not enough consecutive declining readings -- attenuate score
            let temporalFactor = Double(_consecutiveDecliningCount)
                / Double(DrowsinessConstants.requiredConsecutiveReadings)
            rawScore = (hrvSignal * DrowsinessConstants.hrvDeclineWeight
                + hrSignal * DrowsinessConstants.hrDeclineWeight
                + motionSignal * DrowsinessConstants.motionReductionWeight) * temporalFactor * 0.5
        }

        let score = clamp(rawScore, 0.0, 1.0)
        _currentScore = score

        // 4. Determine level from score
        let newLevel = levelFromScore(score)
        let previousLevel = _currentLevel
        _currentLevel = newLevel

        // Capture mutable state before unlocking to avoid data race
        let consecutiveCount = _consecutiveDecliningCount

        lock.unlock()

        // 5. Log level transitions
        #if DEBUG
        if newLevel != previousLevel {
            logInfo(
                "DrowsinessDetector: level changed \(previousLevel.displayName) -> \(newLevel.displayName) "
                + "(score=\(String(format: "%.2f", score)), "
                + "consecutive=\(consecutiveCount))",
                category: .stateEngine
            )
        } else {
            logDebug(
                "DrowsinessDetector: score=\(String(format: "%.2f", score)) "
                + "level=\(newLevel.displayName) "
                + "(HRV=\(String(format: "%.2f", hrvSignal)) "
                + "HR=\(String(format: "%.2f", hrSignal)) "
                + "Motion=\(String(format: "%.2f", motionSignal)) "
                + "consec=\(consecutiveCount))",
                category: .stateEngine
            )
        }
        #endif
    }

    // MARK: - Music Recommendation

    /// Returns the current drowsiness-aware music recommendation.
    /// Safety: ONLY adjusts music parameters. No UI, no alerts.
    var currentRecommendation: DrowsinessMusicRecommendation {
        lock.lock()
        let level = _currentLevel
        lock.unlock()

        return DrowsinessMusicRecommendation(
            level: level,
            bpmBoost: level.bpmBoost,
            minimumEnergy: level.shouldTriggerAlertingMusic
                ? DrowsinessConstants.alertingEnergyFloor
                : 0.0,
            preferLouder: level.shouldTriggerAlertingMusic
        )
    }

    // MARK: - Signal Computation

    /// Computes normalized HRV decline signal (0-1) relative to personal baseline.
    private func computeHRVDeclineSignal() -> Double {
        guard hrvBuffer.count >= 3 else { return 0.0 }

        let baseline = personalBaseline.currentBaseline
        guard baseline > 0 else { return 0.0 }

        // Compute average of recent readings
        let recentAvg = hrvBuffer.suffix(3).map(\.value).reduce(0, +) / 3.0

        // Decline = how far below baseline
        let declineFraction = (baseline - recentAvg) / baseline
        guard declineFraction > 0 else { return 0.0 }

        // Also check for downward trend within the buffer
        let trendSignal = computeDownwardTrend(hrvBuffer)

        // Combine absolute decline with trend
        let absoluteSignal = clamp(
            declineFraction / DrowsinessConstants.hrvDeclineNormalizationFraction,
            0.0, 1.0
        )

        return clamp(absoluteSignal * 0.6 + trendSignal * 0.4, 0.0, 1.0)
    }

    /// Computes normalized HR decline signal (0-1) relative to session average.
    private func computeHRDeclineSignal() -> Double {
        guard hrBuffer.count >= 3, sessionHRCount > 0 else { return 0.0 }

        let sessionAvg = sessionHRSum / Double(sessionHRCount)
        guard sessionAvg > 0 else { return 0.0 }

        // Average of recent readings
        let recentAvg = hrBuffer.suffix(3).map(\.value).reduce(0, +) / 3.0

        // Decline = how far below session average
        let decline = sessionAvg - recentAvg
        guard decline > 0 else { return 0.0 }

        let absoluteSignal = clamp(
            decline / DrowsinessConstants.hrDeclineNormalizationBPM,
            0.0, 1.0
        )

        // Also check for downward trend
        let trendSignal = computeDownwardTrend(hrBuffer)

        return clamp(absoluteSignal * 0.6 + trendSignal * 0.4, 0.0, 1.0)
    }

    /// Computes normalized motion reduction signal (0-1).
    private func computeMotionReductionSignal() -> Double {
        guard motionBuffer.count >= 3 else { return 0.0 }

        let recentAvg = motionBuffer.suffix(3).map(\.value).reduce(0, +) / 3.0

        // Very still = high signal
        if recentAvg < DrowsinessConstants.motionStillThreshold {
            return 0.9
        }

        // Scale inversely against baseline driving motion
        let reductionRatio = 1.0
            - (recentAvg / DrowsinessConstants.baselineMotionMagnitude)
        guard reductionRatio > 0 else { return 0.0 }

        return clamp(reductionRatio, 0.0, 1.0)
    }

    // MARK: - Trend Analysis

    /// Computes a downward trend signal (0-1) from a timestamped buffer.
    /// Uses simple linear regression slope: negative slope = downward trend.
    private func computeDownwardTrend(_ buffer: [(timestamp: Date, value: Double)]) -> Double {
        guard buffer.count >= 3 else { return 0.0 }

        // Simple slope estimation: compare first half average to second half average
        let midpoint = buffer.count / 2
        let firstHalf = buffer.prefix(midpoint)
        let secondHalf = buffer.suffix(buffer.count - midpoint)

        guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return 0.0 }

        let firstAvg = firstHalf.map(\.value).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map(\.value).reduce(0, +) / Double(secondHalf.count)

        // Negative delta = declining
        let delta = firstAvg - secondAvg
        guard delta > 0, firstAvg > 0 else { return 0.0 }

        // Normalize: a 20% decline from first half = 1.0 trend signal
        let declinePercent = delta / firstAvg
        return clamp(declinePercent / 0.20, 0.0, 1.0)
    }

    // MARK: - Level Classification

    /// Maps a composite score to a drowsiness level.
    private func levelFromScore(_ score: Double) -> DrowsinessLevel {
        if score >= DrowsinessConstants.severeThreshold { return .severeDrowsiness }
        if score >= DrowsinessConstants.moderateThreshold { return .moderateDrowsiness }
        if score >= DrowsinessConstants.mildThreshold { return .mildDrowsiness }
        return .alert
    }

    // MARK: - Buffer Management

    /// Removes readings from a buffer that are older than the given date.
    private func pruneBuffer(
        _ buffer: inout [(timestamp: Date, value: Double)],
        before cutoff: Date
    ) {
        buffer.removeAll { $0.timestamp < cutoff }
    }

    // MARK: - Reset

    /// Resets the detector to initial state. Called when a commute session ends
    /// or when CarPlay disconnects.
    func reset() {
        lock.lock()
        _currentLevel = .alert
        _currentScore = 0.0
        _consecutiveDecliningCount = 0
        hrvBuffer.removeAll()
        hrBuffer.removeAll()
        motionBuffer.removeAll()
        sessionHRSum = 0.0
        sessionHRCount = 0
        lock.unlock()

        logInfo("DrowsinessDetector reset", category: .stateEngine)
    }

    // MARK: - Utilities

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}

#endif
