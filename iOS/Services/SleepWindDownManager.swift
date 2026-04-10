//
//  SleepWindDownManager.swift
//  Resonance
//
//  Manages the Sleep Wind-Down Mode (E5): detects pre-sleep biometric
//  signals, auto-suggests sleep mode, orchestrates a gradual volume fade
//  to zero over the final 10 minutes, and correlates next-morning
//  HealthKit sleep data with wind-down session metrics.
//
//  Detection composite: wristTempTrend + hrvTrend + motionLevel +
//  hourOfDay + circadianPhase. Requires 3+ aligned signals for 5+
//  minutes before suggesting sleep mode.
//
//  Thread-safe via NSLock, matching the PersonalBaseline/DrowsinessDetector
//  pattern. Volume fade uses AVAudioSession with a repeating Timer.
//
//  Research citations:
//  - Walker 2017, "Why We Sleep": pre-sleep core body temperature decline
//    is a primary sleep onset trigger.
//  - Ohayon et al., Sleep Medicine Reviews 2017: HRV rise before sleep
//    reflects parasympathetic dominance and imminent sleep onset.
//  - Trinder et al., J Sleep Res 2001: reduced motor activity is a
//    reliable predictor of sleep onset within 15-30 minutes.
//
//  Integration: DecisionEngine (sleep arc), SessionPlanner (.sleepWindDown)
//

#if os(iOS)

import Foundation
import AVFoundation

// MARK: - Sleep Wind-Down Constants

/// Named constants for the sleep wind-down detection and fade subsystem.
enum SleepWindDownConstants {

    // MARK: - Detection Thresholds

    /// Hour of day (24h) after which sleep detection becomes active.
    /// Pre-sleep monitoring only runs after 9:00 PM.
    static let detectionStartHour: Int = 21

    /// Hour of day (24h) before which sleep detection remains active (next day).
    /// Covers late-night users up to 3:00 AM.
    static let detectionEndHour: Int = 3

    /// Number of aligned signals (out of 5) required to suggest sleep mode.
    static let requiredAlignedSignals: Int = 3

    /// Duration in seconds that signals must remain aligned before suggestion.
    /// 5 minutes = 300 seconds.
    static let alignmentDurationSeconds: TimeInterval = 300.0

    // MARK: - Signal Weights

    /// Weight of wrist temperature trend in composite score.
    static let wristTempWeight: Double = 0.25

    /// Weight of HRV trend in composite score.
    static let hrvTrendWeight: Double = 0.25

    /// Weight of motion reduction in composite score.
    static let motionWeight: Double = 0.20

    /// Weight of hour-of-day signal in composite score.
    static let hourWeight: Double = 0.15

    /// Weight of circadian phase proximity in composite score.
    static let circadianPhaseWeight: Double = 0.15

    // MARK: - Wrist Temperature

    /// Minimum temperature decline (degrees C) over the observation window
    /// to indicate pre-sleep thermoregulatory shift.
    static let wristTempDeclineThreshold: Double = 0.3

    /// Observation window in seconds for wrist temperature trend (20 min).
    static let wristTempWindowSeconds: TimeInterval = 1200.0

    // MARK: - HRV

    /// Minimum HRV rise fraction (above recent average) to indicate
    /// parasympathetic dominance. A 15% rise is significant.
    static let hrvRiseFraction: Double = 0.15

    /// Observation window in seconds for HRV trend analysis (10 min).
    static let hrvWindowSeconds: TimeInterval = 600.0

    // MARK: - Motion

    /// Accelerometer magnitude below which the user is considered very still.
    static let motionStillThreshold: Double = 0.02

    /// Sustained low-motion reading count required (at ~30s intervals, 10 = 5 min).
    static let motionStillReadingCount: Int = 10

    // MARK: - Volume Fade

    /// Duration in seconds over which volume fades from current level to zero.
    /// 10 minutes = 600 seconds.
    static let volumeFadeDurationSeconds: TimeInterval = 600.0

    /// Interval in seconds between volume adjustment steps during fade.
    /// Every 10 seconds = 60 steps over 10 minutes for smooth fade.
    static let volumeFadeStepIntervalSeconds: TimeInterval = 10.0

    // MARK: - Buffers

    /// Maximum number of biometric readings retained per signal buffer.
    static let maxBufferSize: Int = 30  // ~15 minutes at 30s intervals

    /// Maximum age of buffered readings before pruning (seconds).
    static let bufferWindowSeconds: TimeInterval = 900.0  // 15 minutes

    // MARK: - Session

    /// Minimum session duration in seconds to generate a report (5 min).
    static let minimumSessionDurationSeconds: TimeInterval = 300.0

    /// Maximum time in seconds to wait for next-morning sleep data (12 hours).
    static let sleepDataWaitWindowSeconds: TimeInterval = 43_200.0

    // MARK: - Persistence

    /// UserDefaults key prefix for sleep wind-down persistence.
    static let persistenceKeyPrefix = "com.y4sh.resonance.sleepWindDown"
}

// MARK: - Sleep Wind-Down State

/// Lifecycle states for the sleep wind-down mode.
enum SleepWindDownState: String, Codable, CaseIterable, Sendable {
    /// Sleep mode is not active and detection is not running.
    case inactive

    /// Biometric signals are being monitored for pre-sleep patterns.
    /// Entered automatically after the detection start hour.
    case preDetection

    /// Pre-sleep signals have aligned for the required duration.
    /// The user is shown a suggestion to activate sleep mode.
    case suggested

    /// Sleep wind-down session is actively running. Music arc is
    /// following the sleep template from SessionPlanner.
    case active

    /// Final phase: volume is fading from current level to zero
    /// over the configured fade duration (default 10 minutes).
    case fadingOut

    /// Session has completed. Volume reached zero, playback stopped.
    /// Next-morning correlation will run after wake.
    case completed

    /// Human-readable display name for logging and UI.
    var displayName: String {
        switch self {
        case .inactive: return "Inactive"
        case .preDetection: return "Monitoring"
        case .suggested: return "Suggested"
        case .active: return "Active"
        case .fadingOut: return "Fading Out"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Sleep Detection Signals

/// Snapshot of biometric and contextual signals used to determine
/// whether the user is approaching sleep onset.
struct SleepDetectionSignals: Sendable {
    /// Wrist temperature trend: negative values indicate cooling (pre-sleep).
    /// Measured in degrees Celsius change over the observation window.
    let wristTempTrend: Double

    /// HRV trend: positive values indicate rising HRV (parasympathetic dominance).
    /// Measured as fractional change from recent average.
    let hrvTrend: Double

    /// Current motion level from accelerometer magnitude.
    /// Lower values indicate less movement (approaching stillness).
    let motionLevel: Double

    /// Current hour of day in 24-hour format (0-23).
    let hourOfDay: Int

    /// Current circadian phase based on the user's learned profile.
    /// Values near 1.0 indicate proximity to typical sleep hour.
    let circadianPhase: Double

    /// Number of individual signals currently indicating pre-sleep state.
    var alignedSignalCount: Int {
        var count = 0
        if wristTempTrend < -SleepWindDownConstants.wristTempDeclineThreshold { count += 1 }
        if hrvTrend > SleepWindDownConstants.hrvRiseFraction { count += 1 }
        if motionLevel < SleepWindDownConstants.motionStillThreshold { count += 1 }
        if isLateHour { count += 1 }
        if circadianPhase > 0.7 { count += 1 }
        return count
    }

    /// Whether the current hour falls within the detection window.
    var isLateHour: Bool {
        hourOfDay >= SleepWindDownConstants.detectionStartHour
            || hourOfDay < SleepWindDownConstants.detectionEndHour
    }

    /// Weighted composite score (0.0-1.0) across all five signals.
    var compositeScore: Double {
        let tempSignal = min(1.0, max(0.0,
            -wristTempTrend / SleepWindDownConstants.wristTempDeclineThreshold))
        let hrvSignal = min(1.0, max(0.0,
            hrvTrend / SleepWindDownConstants.hrvRiseFraction))
        let motionSignal = min(1.0, max(0.0,
            1.0 - (motionLevel / 0.1)))
        let hourSignal: Double = isLateHour ? 1.0 : 0.0
        let phaseSignal = min(1.0, max(0.0, circadianPhase))

        return tempSignal * SleepWindDownConstants.wristTempWeight
            + hrvSignal * SleepWindDownConstants.hrvTrendWeight
            + motionSignal * SleepWindDownConstants.motionWeight
            + hourSignal * SleepWindDownConstants.hourWeight
            + phaseSignal * SleepWindDownConstants.circadianPhaseWeight
    }
}

// MARK: - Sleep Wind-Down Report

/// Post-session report correlating wind-down metrics with next-morning
/// HealthKit sleep data. Consumed by the session summary UI.
struct SleepWindDownReport: Codable, Sendable {
    /// Total duration of the wind-down session in minutes.
    let sessionDuration: Double

    /// Number of tracks played during the session.
    let tracksPlayed: Int

    // SECURITY: No raw biometric values persisted
    /// Categorical relaxation depth at session end ("good", "fair", or "poor").
    let relaxationCategory: String

    /// Time in minutes from session end to detected sleep onset.
    /// Derived from HealthKit sleep analysis. Nil if data unavailable.
    let sleepOnsetLatency: Double?

    /// Change in HealthKit sleep quality score compared to the user's
    /// 7-day average. Positive values mean better sleep.
    /// Nil if insufficient historical data.
    let sleepQualityDelta: Double?

    /// Timestamp when the session started.
    let sessionStartedAt: Date

    /// Timestamp when the session completed (volume reached zero).
    let sessionCompletedAt: Date

    /// Average composite detection score during the session.
    let averageCompositeScore: Double

    /// Human-readable summary for the morning feedback UI.
    var feedbackMessage: String? {
        guard let delta = sleepQualityDelta else { return nil }
        let percentChange = Int(abs(delta * 100))
        if delta > 0.05 {
            return "Your sleep quality appeared to be \(percentChange)% better after last night's wind-down session"
        } else if delta < -0.05 {
            return "Your sleep quality appeared to be \(percentChange)% lower than your average last night"
        } else {
            return "Your sleep quality appeared to be consistent with your recent average"
        }
    }
}

// MARK: - Sleep Wind-Down Session Metrics

/// Mutable accumulator for in-progress session metrics.
/// Internal to SleepWindDownManager; snapshotted into SleepWindDownReport.
private struct SleepSessionMetrics {
    var startTime: Date = Date()
    var tracksPlayed: Int = 0
    var finalHRV: Double = 0.0
    var compositeScoreSum: Double = 0.0
    var compositeScoreCount: Int = 0
    var endTime: Date?

    var averageCompositeScore: Double {
        compositeScoreCount > 0
            ? compositeScoreSum / Double(compositeScoreCount)
            : 0.0
    }

    var durationMinutes: Double {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime) / 60.0
    }
}

// MARK: - Sleep Wind-Down Manager

/// Orchestrates the sleep wind-down lifecycle: pre-sleep detection,
/// session management, volume fade, and next-morning sleep correlation.
///
/// Thread-safe via NSLock. Follows the DrowsinessDetector pattern:
/// buffered biometric readings, composite scoring, temporal gating.
///
/// Integration points:
/// - DecisionEngine: consult `currentState` to enable sleep arc scoring
/// - SessionPlanner: uses `.sleepWindDown` template when state is `.active`
/// - HealthKitService: fetches next-morning sleep data for correlation
/// - CircadianProfileManager: provides user's typical sleep hour for phase signal
final class SleepWindDownManager {

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - Dependencies

    private let circadianProfileManager: CircadianProfileManager
    private let defaults: UserDefaults

    // MARK: - State

    private var _currentState: SleepWindDownState = .inactive
    private var _alignmentStartDate: Date?
    private var _sessionMetrics: SleepSessionMetrics?
    private var _lastReport: SleepWindDownReport?

    /// Thread-safe read of the current wind-down state.
    var currentState: SleepWindDownState {
        lock.lock(); defer { lock.unlock() }; return _currentState
    }

    /// Whether the sleep wind-down mode is currently active (active, fading out, or suggested).
    var isActive: Bool {
        let state = currentState
        return state == .active || state == .fadingOut || state == .suggested
    }

    /// Thread-safe read of the last completed session report.
    var lastReport: SleepWindDownReport? {
        lock.lock(); defer { lock.unlock() }; return _lastReport
    }

    // MARK: - Signal Buffers

    /// Recent wrist temperature readings for trend analysis.
    private var wristTempBuffer: [(timestamp: Date, value: Double)] = []

    /// Recent HRV readings for trend analysis.
    private var hrvBuffer: [(timestamp: Date, value: Double)] = []

    /// Recent motion readings for stillness detection.
    private var motionBuffer: [(timestamp: Date, value: Double)] = []

    // MARK: - Volume Fade

    /// Timer driving the gradual volume reduction.
    private var fadeTimer: Timer?

    /// Volume level at the start of the fade (captured when fade begins).
    private var fadeStartVolume: Float = 0.0

    /// Number of fade steps completed so far.
    private var fadeStepsCompleted: Int = 0

    /// Total number of fade steps for the full fade duration.
    private var fadeTotalSteps: Int {
        max(1, Int(SleepWindDownConstants.volumeFadeDurationSeconds
            / SleepWindDownConstants.volumeFadeStepIntervalSeconds))
    }

    // MARK: - Persistence Keys

    private enum Keys {
        static let lastReportData = "\(SleepWindDownConstants.persistenceKeyPrefix).lastReport"
        static let lastSessionDate = "\(SleepWindDownConstants.persistenceKeyPrefix).lastSessionDate"
    }

    // MARK: - Initialization

    /// Convenience initializer using a default CircadianProfileManager.
    convenience init() {
        self.init(circadianProfileManager: CircadianProfileManager())
    }

    init(
        circadianProfileManager: CircadianProfileManager,
        defaults: UserDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
    ) {
        self.circadianProfileManager = circadianProfileManager
        self.defaults = defaults
        self._lastReport = Self.loadLastReport(from: defaults)

        logDebug("SleepWindDownManager initialized", category: .stateEngine)
    }

    // MARK: - Main Update

    /// Processes a new biometric reading and advances the wind-down state machine.
    ///
    /// Called each StateEngine cycle (~30s). Buffers signals, computes detection,
    /// and transitions state when thresholds are met.
    ///
    /// - Parameter biometric: Current biometric signal from Apple Watch.
    func processReading(biometric: BiometricSignal?) {
        lock.lock()

        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        // Prune old readings
        pruneBuffer(&wristTempBuffer, before: now.addingTimeInterval(
            -SleepWindDownConstants.bufferWindowSeconds))
        pruneBuffer(&hrvBuffer, before: now.addingTimeInterval(
            -SleepWindDownConstants.bufferWindowSeconds))
        pruneBuffer(&motionBuffer, before: now.addingTimeInterval(
            -SleepWindDownConstants.bufferWindowSeconds))

        // Buffer new readings
        if let hrv = biometric?.hrv, hrv > 0 {
            hrvBuffer.append((timestamp: now, value: hrv))
            if hrvBuffer.count > SleepWindDownConstants.maxBufferSize {
                hrvBuffer.removeFirst()
            }
        }

        let motionMag = biometric?.accelerometerMagnitude ?? 0.0
        motionBuffer.append((timestamp: now, value: motionMag))
        if motionBuffer.count > SleepWindDownConstants.maxBufferSize {
            motionBuffer.removeFirst()
        }

        // Update session metrics if active
        if let metrics = _sessionMetrics, _currentState == .active || _currentState == .fadingOut {
            _sessionMetrics?.finalHRV = biometric?.hrv ?? metrics.finalHRV
        }

        let previousState = _currentState

        // State machine transitions
        switch _currentState {
        case .inactive:
            if isWithinDetectionWindow(hour: currentHour) {
                _currentState = .preDetection
                logInfo("SleepWindDown: entering pre-detection (hour=\(currentHour))",
                        category: .stateEngine)
            }

        case .preDetection:
            if !isWithinDetectionWindow(hour: currentHour) {
                _currentState = .inactive
                _alignmentStartDate = nil
                clearBuffers()
            } else {
                let signals = computeCurrentSignals(hour: currentHour)
                if signals.alignedSignalCount >= SleepWindDownConstants.requiredAlignedSignals {
                    if let alignStart = _alignmentStartDate {
                        let elapsed = now.timeIntervalSince(alignStart)
                        if elapsed >= SleepWindDownConstants.alignmentDurationSeconds {
                            _currentState = .suggested
                            logInfo(
                                "SleepWindDown: suggesting sleep mode "
                                + "(aligned=\(signals.alignedSignalCount), "
                                + "composite=\(String(format: "%.2f", signals.compositeScore)))",
                                category: .stateEngine)
                        }
                    } else {
                        _alignmentStartDate = now
                    }
                } else {
                    _alignmentStartDate = nil
                }

                // Track composite score
                if var metrics = _sessionMetrics {
                    metrics.compositeScoreSum += signals.compositeScore
                    metrics.compositeScoreCount += 1
                    _sessionMetrics = metrics
                }
            }

        case .suggested:
            // Stays in suggested until the user accepts or dismisses,
            // or signals drop below threshold and we revert to preDetection.
            let signals = computeCurrentSignals(hour: currentHour)
            if signals.alignedSignalCount < SleepWindDownConstants.requiredAlignedSignals {
                _currentState = .preDetection
                _alignmentStartDate = nil
                logInfo("SleepWindDown: suggestion withdrawn (signals dropped)",
                        category: .stateEngine)
            }

        case .active:
            // Session is running; accumulate metrics
            if var metrics = _sessionMetrics {
                let signals = computeCurrentSignals(hour: currentHour)
                metrics.compositeScoreSum += signals.compositeScore
                metrics.compositeScoreCount += 1
                _sessionMetrics = metrics
            }

        case .fadingOut:
            // Volume fade is managed by the Timer; nothing to do here
            break

        case .completed:
            // Stay completed until explicitly reset
            break
        }

        if _currentState != previousState {
            logInfo(
                "SleepWindDown: state changed \(previousState.displayName) "
                + "-> \(_currentState.displayName)",
                category: .stateEngine)
        }

        lock.unlock()
    }

    // MARK: - User Actions

    /// Called when the user accepts the sleep mode suggestion.
    /// Transitions from `.suggested` to `.active` and begins the session.
    func activateSleepMode() {
        lock.lock()
        guard _currentState == .suggested || _currentState == .preDetection else {
            let stateName = _currentState.displayName
            lock.unlock()
            logWarning("SleepWindDown: cannot activate from state \(stateName)",
                       category: .stateEngine)
            return
        }

        _currentState = .active
        _sessionMetrics = SleepSessionMetrics(startTime: Date())
        lock.unlock()

        logInfo("SleepWindDown: sleep mode activated by user", category: .stateEngine)
    }

    /// Called when the user manually initiates sleep mode (bypasses detection).
    /// Can be called from any state except `.fadingOut` or `.completed`.
    func manualActivate() {
        lock.lock()
        guard _currentState != .fadingOut, _currentState != .completed else {
            lock.unlock()
            return
        }

        _currentState = .active
        _sessionMetrics = SleepSessionMetrics(startTime: Date())
        lock.unlock()

        logInfo("SleepWindDown: manual activation", category: .stateEngine)
    }

    /// Called when the user dismisses the sleep suggestion.
    /// Returns to `.preDetection` for continued monitoring.
    func dismissSuggestion() {
        lock.lock()
        guard _currentState == .suggested else {
            lock.unlock()
            return
        }
        _currentState = .preDetection
        _alignmentStartDate = nil
        lock.unlock()

        logInfo("SleepWindDown: suggestion dismissed by user", category: .stateEngine)
    }

    /// Increments the track counter for the active session.
    func recordTrackPlayed() {
        lock.lock()
        _sessionMetrics?.tracksPlayed += 1
        lock.unlock()
    }

    // MARK: - Volume Fade

    /// Begins the volume fade-out. Transitions from `.active` to `.fadingOut`.
    /// Must be called on the main thread (Timer requires a run loop).
    func beginVolumeFade() {
        lock.lock()
        guard _currentState == .active else {
            let stateName = _currentState.displayName
            lock.unlock()
            logWarning("SleepWindDown: cannot begin fade from state \(stateName)",
                       category: .stateEngine)
            return
        }

        _currentState = .fadingOut
        lock.unlock()

        // Capture current system volume
        let audioSession = AVAudioSession.sharedInstance()
        fadeStartVolume = audioSession.outputVolume
        fadeStepsCompleted = 0

        // Schedule repeating timer on main run loop
        DispatchQueue.main.async { [weak self] in
            self?.fadeTimer?.invalidate()
            self?.fadeTimer = Timer.scheduledTimer(withTimeInterval: SleepWindDownConstants.volumeFadeStepIntervalSeconds, repeats: true) { [weak self] _ in
                self?.fadeTimerTick()
            }
        }

        logInfo(
            "SleepWindDown: volume fade started (from \(String(format: "%.2f", fadeStartVolume)), "
            + "steps=\(fadeTotalSteps), interval=\(SleepWindDownConstants.volumeFadeStepIntervalSeconds)s)",
            category: .stateEngine)
    }

    /// Timer callback for each volume fade step.
    private func fadeTimerTick() {
        fadeStepsCompleted += 1

        let progress = min(1.0, Double(fadeStepsCompleted) / Double(fadeTotalSteps))
        let targetVolume = fadeStartVolume * Float(1.0 - progress)

        // Use MPVolumeView-based approach for system volume control.
        // AVAudioSession.outputVolume is read-only; the actual volume change
        // is applied through the system volume slider or MPVolumeView.
        // For now, post a notification that the playback layer can observe
        // to adjust its own output gain.
        NotificationCenter.default.post(
            name: .sleepWindDownVolumeChanged,
            object: nil,
            userInfo: [
                "targetVolume": targetVolume,
                "progress": progress
            ]
        )

        logDebug(
            "SleepWindDown: fade step \(fadeStepsCompleted)/\(fadeTotalSteps) "
            + "volume=\(String(format: "%.3f", targetVolume))",
            category: .stateEngine)

        if fadeStepsCompleted >= fadeTotalSteps {
            completeFade()
        }
    }

    /// Finalizes the volume fade and transitions to `.completed`.
    private func completeFade() {
        DispatchQueue.main.async { [weak self] in
            self?.fadeTimer?.invalidate()
            self?.fadeTimer = nil
        }

        lock.lock()
        _currentState = .completed
        _sessionMetrics?.endTime = Date()

        // Snapshot metrics into a partial report (sleep correlation added later)
        // SECURITY: No raw biometric values persisted
        if let metrics = _sessionMetrics,
           metrics.durationMinutes >= SleepWindDownConstants.minimumSessionDurationSeconds / 60.0 {
            let relaxation = Self.categorizeRelaxation(hrv: metrics.finalHRV)
            let report = SleepWindDownReport(
                sessionDuration: metrics.durationMinutes,
                tracksPlayed: metrics.tracksPlayed,
                relaxationCategory: relaxation,
                sleepOnsetLatency: nil,
                sleepQualityDelta: nil,
                sessionStartedAt: metrics.startTime,
                sessionCompletedAt: metrics.endTime ?? Date(),
                averageCompositeScore: metrics.averageCompositeScore
            )
            _lastReport = report
            persistReport(report)
        }

        lock.unlock()

        // Post completion notification
        NotificationCenter.default.post(
            name: .sleepWindDownVolumeChanged,
            object: nil,
            userInfo: [
                "targetVolume": Float(0.0),
                "progress": 1.0
            ]
        )

        logInfo("SleepWindDown: session completed, volume at zero", category: .stateEngine)
    }

    // MARK: - Sleep Quality Correlation

    /// Fetches next-morning HealthKit sleep data and correlates it with
    /// the wind-down session. Call this after the user wakes up (e.g.,
    /// during the morning StateEngine cycle).
    ///
    /// - Parameter healthKit: HealthKit service for sleep data retrieval.
    func correlateSleepQuality(using healthKit: HealthKitServiceProtocol) async {
        lock.lock()
        guard let report = _lastReport else {
            lock.unlock()
            logDebug("SleepWindDown: no report to correlate", category: .stateEngine)
            return
        }

        // Only correlate if the session was recent (within 12 hours)
        let elapsed = Date().timeIntervalSince(report.sessionCompletedAt)
        guard elapsed <= SleepWindDownConstants.sleepDataWaitWindowSeconds else {
            lock.unlock()
            logDebug("SleepWindDown: session too old for correlation", category: .stateEngine)
            return
        }

        // Already correlated?
        guard report.sleepOnsetLatency == nil else {
            lock.unlock()
            return
        }
        lock.unlock()

        do {
            // Fetch sleep data from session end to 12 hours later
            let sleepEnd = report.sessionCompletedAt
                .addingTimeInterval(SleepWindDownConstants.sleepDataWaitWindowSeconds)
            let sessions = try await healthKit.fetchSleepAnalysis(
                from: report.sessionCompletedAt,
                to: sleepEnd
            )

            guard let firstSleep = sessions.first else {
                logInfo("SleepWindDown: no sleep data found for correlation",
                        category: .stateEngine)
                return
            }

            // Sleep onset latency: time from session end to first sleep sample
            let onsetLatency = firstSleep.startDate.timeIntervalSince(
                report.sessionCompletedAt) / 60.0

            // Total sleep duration
            let totalSleepHours = sessions.reduce(0.0) { $0 + $1.durationHours }

            // Deep sleep fraction
            let deepSleepHours = sessions
                .filter { $0.isDeepSleep }
                .reduce(0.0) { $0 + $1.durationHours }
            let deepSleepFraction = totalSleepHours > 0
                ? deepSleepHours / totalSleepHours
                : 0.0

            // Compute a simple sleep quality score (0-1)
            let durationScore = min(1.0, totalSleepHours / 8.0)
            let deepScore = min(1.0, deepSleepFraction / 0.25)
            let onsetScore = max(0.0, 1.0 - (onsetLatency / 60.0))
            let sleepQuality = durationScore * 0.4 + deepScore * 0.35 + onsetScore * 0.25

            // Fetch 7-day average for comparison
            let weekAgoSleepQuality = await fetchWeekAverageSleepQuality(using: healthKit)
            let qualityDelta: Double? = weekAgoSleepQuality.map { sleepQuality - $0 }

            // Update the report with correlation data
            let correlatedReport = SleepWindDownReport(
                sessionDuration: report.sessionDuration,
                tracksPlayed: report.tracksPlayed,
                relaxationCategory: report.relaxationCategory,
                sleepOnsetLatency: max(0, onsetLatency),
                sleepQualityDelta: qualityDelta,
                sessionStartedAt: report.sessionStartedAt,
                sessionCompletedAt: report.sessionCompletedAt,
                averageCompositeScore: report.averageCompositeScore
            )

            lock.lock()
            _lastReport = correlatedReport
            persistReport(correlatedReport)
            lock.unlock()

            #if DEBUG
            logInfo(
                "SleepWindDown: correlation complete "
                + "(onset=\(String(format: "%.1f", onsetLatency))min, "
                + "quality=\(String(format: "%.2f", sleepQuality)), "
                + "delta=\(qualityDelta.map { String(format: "%.2f", $0) } ?? "nil"))",
                category: .stateEngine)
            #endif

        } catch {
            logWarning(
                "SleepWindDown: sleep correlation failed: \(error.localizedDescription)",
                category: .stateEngine)
        }
    }

    /// Fetches average sleep quality over the past 7 days for delta comparison.
    private func fetchWeekAverageSleepQuality(
        using healthKit: HealthKitServiceProtocol
    ) async -> Double? {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return nil
        }

        do {
            let sessions = try await healthKit.fetchSleepAnalysis(from: weekAgo, to: now)
            guard !sessions.isEmpty else { return nil }

            // Group by night (using start date's calendar day)
            var nightlyQualities: [Double] = []
            var currentNightStart: Date?
            var nightSessions: [SleepSession] = []

            for session in sessions.sorted(by: { $0.startDate < $1.startDate }) {
                let sessionDay = calendar.startOfDay(for: session.startDate)
                if let nightStart = currentNightStart, sessionDay != nightStart {
                    // Process previous night
                    let quality = computeNightlyQuality(nightSessions)
                    nightlyQualities.append(quality)
                    nightSessions = []
                }
                currentNightStart = sessionDay
                nightSessions.append(session)
            }

            // Process last night
            if !nightSessions.isEmpty {
                nightlyQualities.append(computeNightlyQuality(nightSessions))
            }

            guard !nightlyQualities.isEmpty else { return nil }
            return nightlyQualities.reduce(0, +) / Double(nightlyQualities.count)

        } catch {
            logDebug("SleepWindDown: failed to fetch week sleep data: \(error.localizedDescription)",
                     category: .stateEngine)
            return nil
        }
    }

    /// Computes a 0-1 quality score for a single night's sleep sessions.
    private func computeNightlyQuality(_ sessions: [SleepSession]) -> Double {
        let totalHours = sessions.reduce(0.0) { $0 + $1.durationHours }
        let deepHours = sessions.filter { $0.isDeepSleep }.reduce(0.0) { $0 + $1.durationHours }
        let deepFraction = totalHours > 0 ? deepHours / totalHours : 0.0

        let durationScore = min(1.0, totalHours / 8.0)
        let deepScore = min(1.0, deepFraction / 0.25)
        return durationScore * 0.55 + deepScore * 0.45
    }

    // MARK: - Signal Computation

    /// Computes the current snapshot of all detection signals.
    private func computeCurrentSignals(hour: Int) -> SleepDetectionSignals {
        let wristTrend = computeWristTempTrend()
        let hrvTrend = computeHRVTrend()
        let motionLvl = computeCurrentMotionLevel()
        let circPhase = computeCircadianPhase(hour: hour)

        return SleepDetectionSignals(
            wristTempTrend: wristTrend,
            hrvTrend: hrvTrend,
            motionLevel: motionLvl,
            hourOfDay: hour,
            circadianPhase: circPhase
        )
    }

    /// Computes wrist temperature trend (negative = cooling = pre-sleep).
    /// Requires external temperature readings to be fed via `addWristTemperature`.
    private func computeWristTempTrend() -> Double {
        guard wristTempBuffer.count >= 3 else { return 0.0 }

        // Compare first-half average to second-half average
        let midpoint = wristTempBuffer.count / 2
        let firstHalf = wristTempBuffer.prefix(midpoint)
        let secondHalf = wristTempBuffer.suffix(wristTempBuffer.count - midpoint)

        guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return 0.0 }

        let firstAvg = firstHalf.map(\.value).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map(\.value).reduce(0, +) / Double(secondHalf.count)

        // Negative = cooling trend
        return secondAvg - firstAvg
    }

    /// Computes HRV trend (positive = rising = parasympathetic onset).
    private func computeHRVTrend() -> Double {
        guard hrvBuffer.count >= 3 else { return 0.0 }

        let midpoint = hrvBuffer.count / 2
        let firstHalf = hrvBuffer.prefix(midpoint)
        let secondHalf = hrvBuffer.suffix(hrvBuffer.count - midpoint)

        guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return 0.0 }

        let firstAvg = firstHalf.map(\.value).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map(\.value).reduce(0, +) / Double(secondHalf.count)

        guard firstAvg > 0 else { return 0.0 }

        // Return fractional change (positive = rising)
        return (secondAvg - firstAvg) / firstAvg
    }

    /// Returns the average motion magnitude from recent readings.
    private func computeCurrentMotionLevel() -> Double {
        guard !motionBuffer.isEmpty else { return 1.0 }
        let recentCount = min(motionBuffer.count, SleepWindDownConstants.motionStillReadingCount)
        let recent = motionBuffer.suffix(recentCount)
        return recent.map(\.value).reduce(0, +) / Double(recent.count)
    }

    /// Computes how close the current hour is to the user's typical sleep time.
    /// Returns 0.0 (far from sleep) to 1.0 (at or past typical sleep hour).
    private func computeCircadianPhase(hour: Int) -> Double {
        guard let profile = circadianProfileManager.currentProfile else {
            // No profile: use hour proximity to midnight as fallback
            let distToMidnight = min(abs(hour - 24), hour)
            return min(1.0, max(0.0, 1.0 - Double(distToMidnight) / 6.0))
        }

        let sleepHour = profile.typicalSleepHour

        // Compute hours until sleep (wrapping around midnight)
        let hoursUntilSleep: Int
        if hour <= sleepHour {
            hoursUntilSleep = sleepHour - hour
        } else {
            hoursUntilSleep = (24 - hour) + sleepHour
        }

        // Within 2 hours of sleep = high phase, linear decay outward
        let leadHours = CircadianConstants.preSleepLeadHours
        if hoursUntilSleep <= leadHours {
            return 1.0
        } else if hoursUntilSleep <= leadHours + 4 {
            return max(0.0, 1.0 - Double(hoursUntilSleep - leadHours) / 4.0)
        } else {
            return 0.0
        }
    }

    // MARK: - External Signal Input

    /// Adds a wrist temperature reading from the Watch connectivity layer.
    /// Called when OvernightTemperatureSensor data arrives via WatchConnectivity.
    ///
    /// - Parameter temperature: Wrist temperature in degrees Celsius.
    func addWristTemperature(_ temperature: Double) {
        lock.lock()
        let now = Date()
        wristTempBuffer.append((timestamp: now, value: temperature))
        if wristTempBuffer.count > SleepWindDownConstants.maxBufferSize {
            wristTempBuffer.removeFirst()
        }
        lock.unlock()
    }

    // MARK: - Detection Window

    /// Whether the given hour falls within the sleep detection window.
    private func isWithinDetectionWindow(hour: Int) -> Bool {
        hour >= SleepWindDownConstants.detectionStartHour
            || hour < SleepWindDownConstants.detectionEndHour
    }

    // MARK: - Buffer Management

    /// Removes readings from a buffer that are older than the given date.
    private func pruneBuffer(
        _ buffer: inout [(timestamp: Date, value: Double)],
        before cutoff: Date
    ) {
        buffer.removeAll { $0.timestamp < cutoff }
    }

    /// Clears all signal buffers.
    private func clearBuffers() {
        wristTempBuffer.removeAll()
        hrvBuffer.removeAll()
        motionBuffer.removeAll()
    }

    // MARK: - Reset

    /// Resets the manager to inactive state. Stops any active fade timer
    /// and clears all buffered data and session metrics.
    func reset() {
        DispatchQueue.main.async { [weak self] in
            self?.fadeTimer?.invalidate()
            self?.fadeTimer = nil
        }

        lock.lock()
        _currentState = .inactive
        _alignmentStartDate = nil
        _sessionMetrics = nil
        fadeStepsCompleted = 0
        fadeStartVolume = 0.0
        clearBuffers()
        lock.unlock()

        logInfo("SleepWindDownManager reset", category: .stateEngine)
    }

    // MARK: - Persistence

    /// Persists the latest report to UserDefaults as JSON.
    private func persistReport(_ report: SleepWindDownReport) {
        do {
            let data = try JSONEncoder().encode(report)
            defaults.set(data, forKey: Keys.lastReportData)
            defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastSessionDate)
        } catch {
            logWarning("SleepWindDown: failed to persist report: \(error.localizedDescription)",
                       category: .stateEngine)
        }
    }

    /// Loads the last persisted report from UserDefaults.
    private static func loadLastReport(from defaults: UserDefaults) -> SleepWindDownReport? {
        guard let data = defaults.data(forKey: Keys.lastReportData) else { return nil }
        do {
            return try JSONDecoder().decode(SleepWindDownReport.self, from: data)
        } catch {
            logWarning("SleepWindDown: failed to decode persisted report: \(error.localizedDescription)",
                       category: .stateEngine)
            return nil
        }
    }

    // MARK: - Utilities

    /// Clamps a value to the given range.
    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    /// Converts a raw HRV value to a categorical relaxation string.
    /// SECURITY: Prevents raw biometric values from being persisted.
    private static func categorizeRelaxation(hrv: Double) -> String {
        if hrv >= 50.0 { return "good" }
        if hrv >= 30.0 { return "fair" }
        return "poor"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted during sleep wind-down volume fade with userInfo keys:
    /// - "targetVolume": Float (0.0-1.0)
    /// - "progress": Double (0.0-1.0)
    static let sleepWindDownVolumeChanged = Notification.Name(
        "com.y4sh.resonance.sleepWindDownVolumeChanged"
    )

    /// Posted when sleep wind-down state changes.
    static let sleepWindDownStateChanged = Notification.Name(
        "com.y4sh.resonance.sleepWindDownStateChanged"
    )
}

#endif
