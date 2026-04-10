//
//  WorkoutRecoveryManager.swift
//  Resonance
//
//  Detects workout-to-recovery transitions from declining heart rate and
//  reduced motion, then guides a recovery arc that steps BPM down toward
//  resting HR over successive tracks.
//
//  Detection algorithm:
//  - HR declining >10 BPM from peak over 2+ minutes
//  - Motion magnitude < 0.3 (user is slowing/still)
//  - No active HKWorkout session
//
//  Recovery arc targets:
//  - BPM decreasing by ~5 BPM/track toward resting HR
//  - HRV recovery rate tracked against PersonalBaseline
//
//  Thread-safe with NSLock (matches SharedStateEngine pattern).
//  (E2: Workout-to-Recovery Auto-Transition)
//

#if os(iOS)

import Foundation

// MARK: - Recovery State

/// Lifecycle states for the workout-to-recovery transition.
enum RecoveryState: String, Sendable, CaseIterable {
    /// No workout detected; manager is idle.
    case inactive
    /// Active workout in progress; tracking peak HR.
    case workoutActive
    /// Transition signals detected; awaiting confirmation window.
    case transitionDetected
    /// Recovery arc in progress; guiding BPM step-down.
    case recoveryActive
    /// Recovery complete; HR has returned near resting baseline.
    case completed
}

// MARK: - Workout Recovery Metrics

/// Snapshot of biometric metrics during the recovery arc.
struct WorkoutRecoveryMetrics: Sendable {
    /// Peak heart rate observed during the workout.
    let workoutPeakHR: Double
    /// Heart rate at the moment recovery was confirmed.
    let recoveryStartHR: Double
    /// Most recent heart rate reading.
    let currentHR: Double
    /// Timestamp when recovery arc began.
    let recoveryStartTime: Date
    /// Personal HRV baseline at recovery start (from PersonalBaseline).
    let baselineHRV: Double
    /// Most recent HRV reading.
    let currentHRV: Double
    /// HRV recovery percentage toward baseline (0.0 - 1.0).
    let hrvRecoveryPercent: Double
    /// Estimated minutes to return HRV to baseline at current rate.
    let timeToBaselineMinutes: Double?
}

// MARK: - Recovery Track Target

/// BPM target for the next recovery track.
struct RecoveryTrackTarget: Sendable {
    /// Recommended BPM for the next track.
    let targetBPM: Double
    /// Recovery arc progress (0.0 = just started, 1.0 = at resting HR).
    let arcProgress: Double
    /// Number of tracks elapsed since recovery began.
    let tracksElapsed: Int
}

// MARK: - Workout Recovery Manager

/// Detects workout-to-recovery transitions and computes a BPM glide path
/// that steps the music tempo down toward the user's resting heart rate.
///
/// Thread-safe via `NSLock`, matching the `SharedStateEngine` pattern.
/// All mutable state is prefixed with `_` and accessed only while holding `lock`.
final class WorkoutRecoveryManager {

    // MARK: - Constants

    /// Internal thresholds extending the shared RecoveryConstants.
    private enum Thresholds {
        /// Minimum duration (seconds) of HR decline before confirming transition.
        static let minDeclineDuration: TimeInterval = 120.0
        /// Number of consecutive declining HR samples required.
        static let minDecliningSamples: Int = 4
        /// HR must drop this many BPM from peak to trigger detection.
        static let hrDeclineFromPeak: Double = RecoveryConstants.hrDeclineThreshold
        /// Motion magnitude ceiling for "user is slowing down".
        static let motionCeiling: Double = RecoveryConstants.motionThreshold
        /// BPM step-down per recovery track.
        static let bpmStepDown: Double = RecoveryConstants.bpmStepDown
        /// HR must be within this margin of resting to consider recovery complete.
        static let restingMargin: Double = 8.0
        /// Maximum recovery duration (minutes) before auto-completing.
        static let maxRecoveryMinutes: TimeInterval = 30.0
        /// Minimum HRV recovery percent to consider recovery complete.
        static let hrvRecoveryCompletionThreshold: Double = 0.85
    }

    // MARK: - Lock

    private let lock = NSLock()

    // MARK: - Mutable State (protected by lock)

    private var _state: RecoveryState = .inactive
    private var _peakHR: Double = 0.0
    private var _recoveryStartHR: Double = 0.0
    private var _recoveryStartTime: Date?
    private var _recoveryStartHRV: Double = 0.0
    private var _latestHR: Double = 0.0
    private var _latestHRV: Double = 0.0
    private var _restingHR: Double = StateEngineConstants.defaultRestingHeartRate
    private var _tracksElapsedInRecovery: Int = 0

    /// Rolling HR samples for decline detection: (timestamp, heartRate).
    private var _hrHistory: [(timestamp: Date, hr: Double)] = []
    private let maxHRHistorySamples = 8

    /// Timestamp when transition was first detected (for confirmation window).
    private var _transitionDetectedAt: Date?

    // MARK: - Dependencies

    private let personalBaseline: PersonalBaseline

    // MARK: - Thread-Safe Accessors

    /// Current recovery state.
    var state: RecoveryState {
        lock.lock(); defer { lock.unlock() }
        return _state
    }

    /// Current recovery metrics snapshot, or nil if not in recovery.
    var currentMetrics: WorkoutRecoveryMetrics? {
        lock.lock(); defer { lock.unlock() }
        return _buildMetrics()
    }

    // MARK: - Initialization

    init(personalBaseline: PersonalBaseline = PersonalBaseline()) {
        self.personalBaseline = personalBaseline
        logInfo("WorkoutRecoveryManager initialized", category: .decisionEngine)
    }

    // MARK: - Public API

    /// Processes a biometric signal update. Call every StateEngine cycle (~30s).
    ///
    /// - Parameters:
    ///   - biometric: Latest biometric signal from Watch (nil if unavailable).
    ///   - restingHeartRate: User's resting HR from HealthKit.
    func processBiometricUpdate(
        biometric: BiometricSignal?,
        restingHeartRate: Double?
    ) {
        lock.lock()
        defer { lock.unlock() }

        if let rhr = restingHeartRate, rhr > 30, rhr < 120 {
            _restingHR = rhr
        }

        guard let bio = biometric, let hr = bio.heartRate, hr > 0 else { return }

        _latestHR = hr
        if let hrv = bio.hrv, hrv > 0 {
            _latestHRV = hrv
        }

        // Append to HR history
        _hrHistory.append((timestamp: Date(), hr: hr))
        if _hrHistory.count > maxHRHistorySamples {
            _hrHistory.removeFirst()
        }

        switch _state {
        case .inactive:
            _handleInactive(bio: bio, hr: hr)
        case .workoutActive:
            _handleWorkoutActive(bio: bio, hr: hr)
        case .transitionDetected:
            _handleTransitionDetected(bio: bio, hr: hr)
        case .recoveryActive:
            _handleRecoveryActive(bio: bio, hr: hr)
        case .completed:
            // Stay completed until reset
            break
        }
    }

    /// Notifies the manager that a new track started during recovery.
    /// Advances the track counter for BPM arc computation.
    func trackDidStart() {
        lock.lock()
        defer { lock.unlock() }
        guard _state == .recoveryActive else { return }
        _tracksElapsedInRecovery += 1
        logDebug(
            "Recovery track \(_tracksElapsedInRecovery) started",
            category: .decisionEngine
        )
    }

    /// Returns the BPM target for the next recovery track, or nil if not recovering.
    func nextTrackTarget() -> RecoveryTrackTarget? {
        lock.lock()
        defer { lock.unlock() }
        guard _state == .recoveryActive else { return nil }
        return _computeTrackTarget()
    }

    /// Resets the manager to `.inactive`. Call when a new workout begins
    /// or the user manually ends recovery.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _resetState()
        logInfo("WorkoutRecoveryManager reset", category: .decisionEngine)
    }

    // MARK: - State Handlers (called while holding lock)

    /// Inactive: watch for a workout to begin.
    private func _handleInactive(bio: BiometricSignal, hr: Double) {
        if bio.isInWorkout {
            _state = .workoutActive
            _peakHR = hr
            _hrHistory.removeAll()
            _hrHistory.append((timestamp: Date(), hr: hr))
            #if DEBUG
            logInfo(
                "Workout detected, tracking peak HR (initial: \(String(format: "%.0f", hr)) BPM)",
                category: .decisionEngine
            )
            #endif
        }
    }

    /// Workout active: track peak HR and detect end-of-workout signals.
    private func _handleWorkoutActive(bio: BiometricSignal, hr: Double) {
        // Update peak HR
        if hr > _peakHR {
            _peakHR = hr
        }

        // If the HKWorkout session ends, immediately check for transition
        if !bio.isInWorkout {
            let decline = _peakHR - hr
            let motionMag = bio.movementMagnitude ?? bio.accelerometerMagnitude
            if decline >= Thresholds.hrDeclineFromPeak && motionMag < Thresholds.motionCeiling {
                _state = .transitionDetected
                _transitionDetectedAt = Date()
                logInfo(
                    String(format: "Workout ended, transition detected (peak: %.0f, current: %.0f, decline: %.0f BPM)",
                           _peakHR, hr, decline),
                    category: .decisionEngine
                )
            } else {
                // Workout ended but HR hasn't dropped enough yet; keep watching
                _checkGradualDecline(bio: bio, hr: hr)
            }
            return
        }

        // Still in workout but HR is declining significantly
        _checkGradualDecline(bio: bio, hr: hr)
    }

    /// Checks for a gradual HR decline pattern even while a workout is nominally active.
    private func _checkGradualDecline(bio: BiometricSignal, hr: Double) {
        guard _hrHistory.count >= Thresholds.minDecliningSamples else { return }

        let recentSamples = Array(_hrHistory.suffix(Thresholds.minDecliningSamples))
        let isConsistentlyDeclining = _isMonotonicallyDeclining(recentSamples.map(\.hr))
        let decline = _peakHR - hr
        let motionMag = bio.movementMagnitude ?? bio.accelerometerMagnitude

        guard isConsistentlyDeclining,
              decline >= Thresholds.hrDeclineFromPeak,
              motionMag < Thresholds.motionCeiling,
              !bio.isInWorkout else { return }

        // Check time span of decline
        if let first = recentSamples.first {
            let elapsed = Date().timeIntervalSince(first.timestamp)
            if elapsed >= Thresholds.minDeclineDuration {
                _state = .transitionDetected
                _transitionDetectedAt = Date()
                logInfo(
                    String(format: "Gradual decline detected (peak: %.0f, current: %.0f, over %.0fs)",
                           _peakHR, hr, elapsed),
                    category: .decisionEngine
                )
            }
        }
    }

    /// Transition detected: confirm over a short window, then begin recovery.
    private func _handleTransitionDetected(bio: BiometricSignal, hr: Double) {
        // If the user resumes a workout, cancel transition
        if bio.isInWorkout {
            _state = .workoutActive
            _transitionDetectedAt = nil
            logInfo("Transition cancelled: workout resumed", category: .decisionEngine)
            return
        }

        // HR climbing back up? Cancel transition.
        let decline = _peakHR - hr
        if decline < Thresholds.hrDeclineFromPeak * 0.5 {
            _state = .workoutActive
            _transitionDetectedAt = nil
            logDebug("Transition cancelled: HR recovered", category: .decisionEngine)
            return
        }

        // Confirm after the decline has sustained for the minimum window
        guard let detectedAt = _transitionDetectedAt else {
            _state = .workoutActive
            return
        }

        let elapsed = Date().timeIntervalSince(detectedAt)
        if elapsed >= Thresholds.minDeclineDuration {
            _state = .recoveryActive
            _recoveryStartHR = hr
            _recoveryStartTime = Date()
            _recoveryStartHRV = _latestHRV > 0 ? _latestHRV : personalBaseline.currentBaseline
            _tracksElapsedInRecovery = 0
            #if DEBUG
            logInfo(
                String(format: "Recovery arc started (startHR: %.0f, peakHR: %.0f, baselineHRV: %.1f)",
                       hr, _peakHR, personalBaseline.currentBaseline),
                category: .decisionEngine
            )
            #endif
        }
    }

    /// Recovery active: track HRV recovery and check for completion.
    private func _handleRecoveryActive(bio: BiometricSignal, hr: Double) {
        // If a new workout starts, reset entirely
        if bio.isInWorkout {
            _resetState()
            _state = .workoutActive
            _peakHR = hr
            logInfo("New workout during recovery: resetting", category: .decisionEngine)
            return
        }

        // Check completion conditions
        let nearResting = hr <= _restingHR + Thresholds.restingMargin
        let hrvRecovery = _computeHRVRecoveryPercent()
        let hrvRecovered = hrvRecovery >= Thresholds.hrvRecoveryCompletionThreshold

        // Time-based auto-completion
        var timedOut = false
        if let startTime = _recoveryStartTime {
            let elapsed = Date().timeIntervalSince(startTime) / 60.0
            timedOut = elapsed >= Thresholds.maxRecoveryMinutes
        }

        if (nearResting && hrvRecovered) || timedOut {
            _state = .completed
            let reason = timedOut ? "timeout" : "HR + HRV targets reached"
            #if DEBUG
            logInfo(
                String(format: "Recovery completed (%@): HR %.0f, HRV recovery %.0f%%",
                       reason, hr, hrvRecovery * 100),
                category: .decisionEngine
            )
            #endif
        }
    }

    // MARK: - Computation Helpers (called while holding lock)

    /// Computes HRV recovery percentage toward personal baseline.
    private func _computeHRVRecoveryPercent() -> Double {
        let baseline = personalBaseline.currentBaseline
        guard baseline > 0, _recoveryStartHRV > 0, _recoveryStartHRV < baseline else {
            // If starting HRV is already at or above baseline, recovery is complete
            return (_latestHRV >= baseline && baseline > 0) ? 1.0 : 0.0
        }
        let range = baseline - _recoveryStartHRV
        guard range > 0 else { return 1.0 }
        let progress = (_latestHRV - _recoveryStartHRV) / range
        return min(max(progress, 0.0), 1.0)
    }

    /// Estimates time to return to HRV baseline in minutes.
    private func _estimateTimeToBaseline() -> Double? {
        let baseline = personalBaseline.currentBaseline
        guard baseline > 0,
              _latestHRV > 0,
              _latestHRV < baseline,
              let startTime = _recoveryStartTime else {
            return nil
        }

        let elapsed = Date().timeIntervalSince(startTime) / 60.0
        guard elapsed > 0.5 else { return nil } // Need at least 30s of data

        let hrvGain = _latestHRV - _recoveryStartHRV
        guard hrvGain > 0 else { return nil }

        let ratePerMinute = hrvGain / elapsed
        guard ratePerMinute > 0 else { return nil }

        let remaining = baseline - _latestHRV
        return remaining / ratePerMinute
    }

    /// Computes the BPM target for the next recovery track.
    private func _computeTrackTarget() -> RecoveryTrackTarget {
        let totalDropNeeded = _recoveryStartHR - _restingHR
        let stepsToResting: Double = totalDropNeeded > 0
            ? ceil(totalDropNeeded / Thresholds.bpmStepDown)
            : 1.0

        let droppedSoFar = Double(_tracksElapsedInRecovery) * Thresholds.bpmStepDown
        let targetBPM = max(_restingHR, _recoveryStartHR - droppedSoFar)

        let arcProgress: Double
        if totalDropNeeded > 0 {
            arcProgress = min(1.0, droppedSoFar / totalDropNeeded)
        } else {
            arcProgress = 1.0
        }

        return RecoveryTrackTarget(
            targetBPM: targetBPM,
            arcProgress: arcProgress,
            tracksElapsed: _tracksElapsedInRecovery
        )
    }

    /// Builds a metrics snapshot from current state. Returns nil if not recovering.
    private func _buildMetrics() -> WorkoutRecoveryMetrics? {
        guard _state == .recoveryActive || _state == .completed,
              let startTime = _recoveryStartTime else { return nil }

        return WorkoutRecoveryMetrics(
            workoutPeakHR: _peakHR,
            recoveryStartHR: _recoveryStartHR,
            currentHR: _latestHR,
            recoveryStartTime: startTime,
            baselineHRV: personalBaseline.currentBaseline,
            currentHRV: _latestHRV,
            hrvRecoveryPercent: _computeHRVRecoveryPercent(),
            timeToBaselineMinutes: _estimateTimeToBaseline()
        )
    }

    /// Checks whether an array of HR values is monotonically declining.
    private func _isMonotonicallyDeclining(_ values: [Double]) -> Bool {
        guard values.count >= 2 else { return false }
        for i in 1..<values.count {
            if values[i] >= values[i - 1] {
                return false
            }
        }
        return true
    }

    /// Resets all mutable state to initial values.
    private func _resetState() {
        _state = .inactive
        _peakHR = 0.0
        _recoveryStartHR = 0.0
        _recoveryStartTime = nil
        _recoveryStartHRV = 0.0
        _latestHR = 0.0
        _latestHRV = 0.0
        _tracksElapsedInRecovery = 0
        _hrHistory.removeAll()
        _transitionDetectedAt = nil
    }
}

#endif
