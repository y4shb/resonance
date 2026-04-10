//
//  AnxietyDetector.swift
//  Resonance
//
//  Composite anxiety detection engine using weighted biometric signals.
//  Combines heart rate deviation, HRV drop rate, wrist temperature increase,
//  and motion reduction into a single anxiety score with hysteresis-based
//  level transitions and episode tracking.
//
//  Research citations:
//  - Chalmers et al., Sensors 2022: multi-signal anxiety detection
//  - Appelhans & Luecken, Psychophysiology 2006: HRV-ANS relationship
//  - Boudreau et al., PMC 2022: circadian HRV variation
//  - Petrescu et al., Frontiers in Psychiatry 2020: wrist temperature & anxiety
//
//  Related files:
//  - StateCalculationHelpers.swift: clamp, circadianHRVFactor
//  - PersonalBaseline.swift: personal HRV baseline with EMA
//  - MusicNeedInference.swift: hysteresis pattern (3-sample debounce)
//

#if os(iOS)

import Foundation

// MARK: - Anxiety Constants

/// Named constants for the anxiety detection subsystem.
enum AnxietyConstants {

    // MARK: - Signal Weights (must sum to 1.0)

    /// Weight of heart rate deviation from baseline in composite score.
    static let hrDeviationWeight: Double = 0.35

    /// Weight of HRV drop rate in composite score.
    static let hrvDropRateWeight: Double = 0.35

    /// Weight of wrist temperature increase in composite score.
    static let wristTempWeight: Double = 0.15

    /// Weight of motion reduction in composite score.
    static let motionReductionWeight: Double = 0.15

    // MARK: - Level Thresholds

    /// Composite score above which state is considered elevated.
    static let elevatedThreshold: Double = 0.4

    /// Composite score above which state is considered anxious.
    static let anxiousThreshold: Double = 0.6

    /// Composite score above which state is considered acute.
    static let acuteThreshold: Double = 0.8

    // MARK: - Hysteresis

    /// Number of consecutive elevated readings required before triggering a level change.
    static let requiredConsecutiveReadings: Int = 3

    /// Time window in seconds over which consecutive readings must occur (~90s at 30s intervals).
    static let hysteresisWindowSeconds: TimeInterval = 90.0

    /// Minimum hold time before allowing a downward level transition (seconds).
    static let downwardHoldSeconds: TimeInterval = 120.0

    // MARK: - Signal Normalization

    /// HR deviation is normalized against this fraction of resting HR.
    /// A deviation of 30% of resting HR maps to a 1.0 signal.
    static let hrDeviationNormalizationFraction: Double = 0.30

    /// HRV drop percentage that maps to a 1.0 signal.
    /// A 40% drop from personal baseline = maximum signal.
    static let hrvDropNormalizationFraction: Double = 0.40

    /// Wrist temperature increase in degrees Celsius that maps to a 1.0 signal.
    /// Anxiety-related peripheral vasoconstriction typically raises wrist temp 0.5-1.5C.
    static let tempIncreaseMaxDegrees: Double = 1.5

    /// Accelerometer magnitude below this is considered "frozen" (anxiety-related stillness).
    static let motionFreezeThreshold: Double = 0.05

    /// Baseline motion magnitude for normalization (typical gentle movement).
    static let baselineMotionMagnitude: Double = 0.3

    // MARK: - Persistence Keys

    // SECURITY: Episode persistence requires encrypted storage (Keychain/CoreData with file protection). Do NOT use UserDefaults.
    // static let episodeHistoryKey = "com.y4sh.resonance.anxietyDetector.episodeHistory"
}

// MARK: - Anxiety Level

/// Severity classification for detected anxiety state.
enum AnxietyLevel: String, Codable, CaseIterable, Sendable {
    /// No significant anxiety indicators.
    case calm

    /// Mild elevation in anxiety signals; monitoring continues.
    case elevated

    /// Clear anxiety pattern detected; music intervention recommended.
    case anxious

    /// Severe anxiety indicators; immediate calming intervention.
    case acute

    /// Numeric severity for comparison (0 = calm, 3 = acute).
    var severity: Int {
        switch self {
        case .calm: return 0
        case .elevated: return 1
        case .anxious: return 2
        case .acute: return 3
        }
    }

    /// Human-readable description for accessibility and logging.
    var displayName: String {
        switch self {
        case .calm: return "Calm"
        case .elevated: return "Elevated"
        case .anxious: return "Anxious"
        case .acute: return "Acute"
        }
    }
}

// MARK: - Anxiety Episode

/// Records a detected anxiety episode for post-session reporting.
struct AnxietyEpisode: Codable, Identifiable, Sendable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var peakScore: Double
    var triggerSignals: [String]
    var tracksDuringEpisode: [EpisodeTrack]
    var hrvBeforeAfter: HRVComparison

    /// Whether the episode has concluded.
    var isActive: Bool { endTime == nil }

    /// Duration of the episode in seconds (ongoing episodes use current time).
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        peakScore: Double = 0.0,
        triggerSignals: [String] = [],
        tracksDuringEpisode: [EpisodeTrack] = [],
        hrvBeforeAfter: HRVComparison = HRVComparison()
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.peakScore = peakScore
        self.triggerSignals = triggerSignals
        self.tracksDuringEpisode = tracksDuringEpisode
        self.hrvBeforeAfter = hrvBeforeAfter
    }
}

/// A track that played during an anxiety episode with biometric impact.
struct EpisodeTrack: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let startedAt: Date
    let hrDuringTrack: Double?
    let hrvDuringTrack: Double?
    /// Positive = biometrics improved, negative = worsened.
    let anxietyScoreChange: Double

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        startedAt: Date = Date(),
        hrDuringTrack: Double? = nil,
        hrvDuringTrack: Double? = nil,
        anxietyScoreChange: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.startedAt = startedAt
        self.hrDuringTrack = hrDuringTrack
        self.hrvDuringTrack = hrvDuringTrack
        self.anxietyScoreChange = anxietyScoreChange
    }
}

/// Before/after HRV comparison for episode reporting.
struct HRVComparison: Codable, Sendable {
    var hrvBefore: Double?
    var hrvAfter: Double?

    /// Positive delta means HRV improved (good).
    var delta: Double? {
        guard let before = hrvBefore, let after = hrvAfter else { return nil }
        return after - before
    }

    /// Whether HRV improved during the episode.
    var improved: Bool {
        guard let d = delta else { return false }
        return d > 0
    }
}

// MARK: - Biometric Snapshot (for timeline)

/// A point-in-time biometric reading captured during an episode.
struct AnxietyBiometricSnapshot: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let heartRate: Double?
    let hrv: Double?
    let anxietyScore: Double

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        heartRate: Double? = nil,
        hrv: Double? = nil,
        anxietyScore: Double = 0.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrv = hrv
        self.anxietyScore = anxietyScore
    }
}

// MARK: - Anxiety Detector

/// Detects anxiety episodes from composite biometric signals with hysteresis-based
/// state transitions. Thread-safe via NSLock for background HealthKit callbacks.
///
/// Composite score formula:
///   score = hrDeviation * 0.35 + hrvDropRate * 0.35 + tempIncrease * 0.15 + motionReduction * 0.15
///
/// Each sub-signal is normalized to 0-1 before weighting. The composite score is then
/// multiplied by a user-configurable sensitivity factor from UserPreferences.
///
/// Hysteresis: Requires 3 consecutive readings at the candidate level within a 90-second
/// window before committing the transition, following the pattern established in
/// MusicNeedInference.applyNeedHysteresis.
final class AnxietyDetector {

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - Dependencies

    private let personalBaseline: PersonalBaseline

    // MARK: - Configuration

    /// User-controlled sensitivity multiplier (0.0 - 1.0).
    /// Loaded from UserPreferences.anxietyInterceptionSensitivity.
    private var _sensitivityMultiplier: Double = 0.5

    var sensitivityMultiplier: Double {
        get { lock.lock(); defer { lock.unlock() }; return _sensitivityMultiplier }
        set { lock.lock(); _sensitivityMultiplier = clamp(newValue, 0.0, 1.0); lock.unlock() }
    }

    // MARK: - Current State

    private var _currentLevel: AnxietyLevel = .calm
    private var _currentScore: Double = 0.0
    private var _activeEpisode: AnxietyEpisode?
    private var _completedEpisodes: [AnxietyEpisode] = []
    private var _biometricTimeline: [AnxietyBiometricSnapshot] = []

    /// Thread-safe read of the current anxiety level.
    var currentLevel: AnxietyLevel {
        lock.lock(); defer { lock.unlock() }; return _currentLevel
    }

    /// Thread-safe read of the current composite score.
    var currentScore: Double {
        lock.lock(); defer { lock.unlock() }; return _currentScore
    }

    /// Thread-safe read of the active episode, if any.
    var activeEpisode: AnxietyEpisode? {
        lock.lock(); defer { lock.unlock() }; return _activeEpisode
    }

    /// Thread-safe read of completed episodes.
    var completedEpisodes: [AnxietyEpisode] {
        lock.lock(); defer { lock.unlock() }; return _completedEpisodes
    }

    /// Thread-safe read of the biometric timeline for the active episode.
    var biometricTimeline: [AnxietyBiometricSnapshot] {
        lock.lock(); defer { lock.unlock() }; return _biometricTimeline
    }

    // MARK: - Hysteresis State

    /// History of candidate levels for hysteresis debounce.
    private var candidateLevelHistory: [AnxietyLevel] = []

    /// Timestamp of the last committed level change.
    private var lastLevelChangeTimestamp: Date?

    /// The level that has been committed through hysteresis.
    private var committedLevel: AnxietyLevel = .calm

    // MARK: - Signal Buffers

    /// Recent HRV values for computing drop rate.
    private var recentHRVReadings: [(timestamp: Date, value: Double)] = []
    private let maxHRVBufferSize = 6  // ~3 minutes at 30s intervals

    /// Baseline wrist temperature for deviation tracking.
    private var baselineWristTemperature: Double?

    /// Recent motion magnitudes for detecting freeze response.
    private var recentMotionReadings: [(timestamp: Date, value: Double)] = []
    private let maxMotionBufferSize = 6

    // MARK: - Initialization

    init(personalBaseline: PersonalBaseline) {
        self.personalBaseline = personalBaseline

        // Load sensitivity from user preferences
        let prefs = UserPreferences.load()
        self._sensitivityMultiplier = prefs.anxietyInterceptionSensitivity

        logDebug("AnxietyDetector initialized (sensitivity: \(String(format: "%.2f", _sensitivityMultiplier)))",
                 category: .stateEngine)
    }

    // MARK: - Main Update

    /// Processes a new biometric reading and updates the anxiety state.
    ///
    /// Called each StateEngine cycle (~30s). Computes the composite anxiety score,
    /// applies hysteresis, manages episode lifecycle, and records biometric snapshots.
    ///
    /// - Parameters:
    ///   - biometric: Current biometric signal from Apple Watch.
    ///   - restingHeartRate: Resting HR from HealthKit (or default).
    ///   - wristTemperature: Optional wrist temperature deviation in Celsius.
    func processReading(
        biometric: BiometricSignal?,
        restingHeartRate: Double,
        wristTemperature: Double?
    ) {
        lock.lock()

        // 1. Compute individual signal components (each 0-1)
        let hrSignal = computeHRDeviationSignal(biometric: biometric, restingHR: restingHeartRate)
        let hrvSignal = computeHRVDropSignal(biometric: biometric)
        let tempSignal = computeWristTempSignal(temperature: wristTemperature)
        let motionSignal = computeMotionReductionSignal(biometric: biometric)

        // 2. Composite weighted score
        let rawScore = hrSignal * AnxietyConstants.hrDeviationWeight
            + hrvSignal * AnxietyConstants.hrvDropRateWeight
            + tempSignal * AnxietyConstants.wristTempWeight
            + motionSignal * AnxietyConstants.motionReductionWeight

        // 3. Apply user sensitivity multiplier.
        //    Sensitivity remaps the score: at 0.5 (default), score is unchanged.
        //    Below 0.5, anxiety detection is less sensitive (score reduced).
        //    Above 0.5, more sensitive (score amplified).
        let sensitivityFactor = 0.5 + _sensitivityMultiplier
        let score = clamp(rawScore * sensitivityFactor, 0.0, 1.0)
        _currentScore = score

        // 4. Determine raw level from score
        let rawLevel = levelFromScore(score)

        // 5. Apply hysteresis (modeled after MusicNeedInference pattern)
        let newLevel = applyHysteresis(rawLevel)

        // 6. Collect trigger signals for episode metadata
        var triggers: [String] = []
        if hrSignal > 0.3 { triggers.append("HR elevated") }
        if hrvSignal > 0.3 { triggers.append("HRV dropping") }
        if tempSignal > 0.3 { triggers.append("Wrist temp rising") }
        if motionSignal > 0.3 { triggers.append("Movement reduced") }

        // 7. Episode lifecycle management
        manageEpisodeLifecycle(newLevel: newLevel, score: score, triggers: triggers, biometric: biometric)

        _currentLevel = newLevel

        // SECURITY: Capture log values BEFORE releasing the lock to avoid data races
        let logScore = score
        let logLevel = newLevel.displayName
        let logHR = hrSignal
        let logHRV = hrvSignal
        let logTemp = tempSignal
        let logMotion = motionSignal

        lock.unlock()

        #if DEBUG
        logDebug(
            "AnxietyDetector: score=\(String(format: "%.2f", logScore)) "
            + "level=\(logLevel) "
            + "(HR=\(String(format: "%.2f", logHR)) "
            + "HRV=\(String(format: "%.2f", logHRV)) "
            + "Temp=\(String(format: "%.2f", logTemp)) "
            + "Motion=\(String(format: "%.2f", logMotion)))",
            category: .stateEngine
        )
        #endif
    }

    // MARK: - Signal Computation

    /// Computes normalized HR deviation signal (0-1).
    /// How much current HR exceeds resting HR, relative to a percentage of resting HR.
    private func computeHRDeviationSignal(biometric: BiometricSignal?, restingHR: Double) -> Double {
        guard let hr = biometric?.heartRate, hr > 0, restingHR > 0 else { return 0.0 }

        // Skip if in workout -- elevated HR is expected
        if biometric?.isInWorkout == true { return 0.0 }

        let deviation = hr - restingHR
        guard deviation > 0 else { return 0.0 }

        let normalizationRange = restingHR * AnxietyConstants.hrDeviationNormalizationFraction
        guard normalizationRange > 0 else { return 0.0 }

        return clamp(deviation / normalizationRange, 0.0, 1.0)
    }

    /// Computes normalized HRV drop signal (0-1).
    /// Measures how much current HRV has dropped below personal baseline.
    private func computeHRVDropSignal(biometric: BiometricSignal?) -> Double {
        guard let hrv = biometric?.hrv, hrv > 0 else { return 0.0 }

        // Buffer the HRV reading
        recentHRVReadings.append((timestamp: Date(), value: hrv))
        if recentHRVReadings.count > maxHRVBufferSize {
            recentHRVReadings.removeFirst()
        }

        let baseline = personalBaseline.currentBaseline
        guard baseline > 0 else { return 0.0 }

        // Drop = how far below baseline, normalized
        let dropFraction = (baseline - hrv) / baseline
        guard dropFraction > 0 else { return 0.0 }

        return clamp(dropFraction / AnxietyConstants.hrvDropNormalizationFraction, 0.0, 1.0)
    }

    /// Computes normalized wrist temperature increase signal (0-1).
    /// Anxiety-related sympathetic activation causes peripheral vasoconstriction,
    /// which can paradoxically increase wrist skin temperature.
    private func computeWristTempSignal(temperature: Double?) -> Double {
        guard let temp = temperature else { return 0.0 }

        // Establish baseline from first reading
        if baselineWristTemperature == nil {
            baselineWristTemperature = temp
            return 0.0
        }

        guard let baseline = baselineWristTemperature else { return 0.0 }

        let increase = temp - baseline
        guard increase > 0 else { return 0.0 }

        return clamp(increase / AnxietyConstants.tempIncreaseMaxDegrees, 0.0, 1.0)
    }

    /// Computes normalized motion reduction signal (0-1).
    /// Anxiety can cause a "freeze" response with reduced movement.
    private func computeMotionReductionSignal(biometric: BiometricSignal?) -> Double {
        let magnitude = biometric?.accelerometerMagnitude ?? 0.0

        // Buffer motion readings
        recentMotionReadings.append((timestamp: Date(), value: magnitude))
        if recentMotionReadings.count > maxMotionBufferSize {
            recentMotionReadings.removeFirst()
        }

        // Need at least 3 readings to judge reduction
        guard recentMotionReadings.count >= 3 else { return 0.0 }

        // Skip if in workout -- reduced motion is irrelevant
        if biometric?.isInWorkout == true { return 0.0 }

        let averageMotion = recentMotionReadings.map(\.value).reduce(0, +)
            / Double(recentMotionReadings.count)

        // If average motion is below freeze threshold, signal is high
        if averageMotion < AnxietyConstants.motionFreezeThreshold {
            return 0.8
        }

        // Otherwise, scale inversely against baseline
        let reductionRatio = 1.0 - (averageMotion / AnxietyConstants.baselineMotionMagnitude)
        return clamp(reductionRatio, 0.0, 1.0)
    }

    // MARK: - Level Classification

    /// Maps a composite score to an anxiety level.
    private func levelFromScore(_ score: Double) -> AnxietyLevel {
        if score >= AnxietyConstants.acuteThreshold { return .acute }
        if score >= AnxietyConstants.anxiousThreshold { return .anxious }
        if score >= AnxietyConstants.elevatedThreshold { return .elevated }
        return .calm
    }

    // MARK: - Hysteresis

    /// Applies hysteresis to prevent rapid oscillation between anxiety levels.
    /// Requires `requiredConsecutiveReadings` (3) consecutive readings at the
    /// candidate level within the hysteresis window before committing.
    ///
    /// Downward transitions (anxiety decreasing) also require a minimum hold time
    /// to prevent premature "all clear" signals.
    ///
    /// Pattern from MusicNeedInference.applyNeedHysteresis.
    private func applyHysteresis(_ rawLevel: AnxietyLevel) -> AnxietyLevel {
        // If raw level matches committed level, clear candidate history
        if rawLevel == committedLevel {
            candidateLevelHistory.removeAll()
            return committedLevel
        }

        candidateLevelHistory.append(rawLevel)

        // Check if we have enough consecutive readings at the same level
        let required = AnxietyConstants.requiredConsecutiveReadings
        let recent = candidateLevelHistory.suffix(required)
        let allAgree = recent.count >= required && recent.allSatisfy { $0 == rawLevel }
        guard allAgree else { return committedLevel }

        // For upward transitions (increasing anxiety), commit immediately after debounce
        if rawLevel.severity > committedLevel.severity {
            committedLevel = rawLevel
            lastLevelChangeTimestamp = Date()
            candidateLevelHistory.removeAll()
            logInfo(
                "Anxiety level escalated to \(rawLevel.displayName) (hysteresis passed)",
                category: .stateEngine
            )
            return committedLevel
        }

        // For downward transitions, enforce hold time to avoid premature de-escalation
        if let lastChange = lastLevelChangeTimestamp,
           Date().timeIntervalSince(lastChange) < AnxietyConstants.downwardHoldSeconds {
            return committedLevel
        }

        committedLevel = rawLevel
        lastLevelChangeTimestamp = Date()
        candidateLevelHistory.removeAll()
        logInfo(
            "Anxiety level de-escalated to \(rawLevel.displayName) (hold time passed)",
            category: .stateEngine
        )
        return committedLevel
    }

    // MARK: - Episode Lifecycle

    /// Manages creation, update, and completion of anxiety episodes.
    private func manageEpisodeLifecycle(
        newLevel: AnxietyLevel,
        score: Double,
        triggers: [String],
        biometric: BiometricSignal?
    ) {
        switch (newLevel, _activeEpisode != nil) {
        case (.calm, false):
            // Normal state, no episode -- nothing to do
            break

        case (_, false) where newLevel.severity >= AnxietyLevel.elevated.severity:
            // Start a new episode
            var episode = AnxietyEpisode(
                startTime: Date(),
                peakScore: score,
                triggerSignals: triggers
            )
            episode.hrvBeforeAfter.hrvBefore = biometric?.hrv
            _activeEpisode = episode
            _biometricTimeline.removeAll()

            // Record initial snapshot
            recordSnapshot(biometric: biometric, score: score)

            logInfo(
                "Anxiety episode started: level=\(newLevel.displayName) score=\(String(format: "%.2f", score))",
                category: .stateEngine
            )

        case (.calm, true):
            // Episode ending -- record final state
            guard var episode = _activeEpisode else { break }
            episode.endTime = Date()
            episode.hrvBeforeAfter.hrvAfter = biometric?.hrv

            recordSnapshot(biometric: biometric, score: score)

            _completedEpisodes.append(episode)
            _activeEpisode = nil

            logInfo(
                "Anxiety episode ended: duration=\(String(format: "%.0f", episode.duration))s "
                + "peakScore=\(String(format: "%.2f", episode.peakScore)) "
                + "hrvImproved=\(episode.hrvBeforeAfter.improved)",
                category: .stateEngine
            )

        case (_, true):
            // Episode ongoing -- update peak score and triggers
            if score > (_activeEpisode?.peakScore ?? 0.0) {
                _activeEpisode?.peakScore = score
            }
            for trigger in triggers where !(_activeEpisode?.triggerSignals.contains(trigger) ?? false) {
                _activeEpisode?.triggerSignals.append(trigger)
            }

            recordSnapshot(biometric: biometric, score: score)

        default:
            break
        }
    }

    /// Records a biometric snapshot for the active episode timeline.
    private func recordSnapshot(biometric: BiometricSignal?, score: Double) {
        let snapshot = AnxietyBiometricSnapshot(
            timestamp: Date(),
            heartRate: biometric?.heartRate,
            hrv: biometric?.hrv,
            anxietyScore: score
        )
        _biometricTimeline.append(snapshot)
    }

    // MARK: - Track Recording

    /// Records a track that played during an active anxiety episode.
    /// Called by the decision engine when a track starts during an episode.
    func recordTrackDuringEpisode(
        title: String,
        artist: String,
        hr: Double?,
        hrv: Double?,
        scoreChange: Double
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard _activeEpisode != nil else { return }

        let track = EpisodeTrack(
            title: title,
            artist: artist,
            hrDuringTrack: hr,
            hrvDuringTrack: hrv,
            anxietyScoreChange: scoreChange
        )
        _activeEpisode?.tracksDuringEpisode.append(track)
    }

    // MARK: - Reporting

    /// Returns the most recent completed episode, if any.
    var lastCompletedEpisode: AnxietyEpisode? {
        lock.lock(); defer { lock.unlock() }
        return _completedEpisodes.last
    }

    /// Returns all completed episodes from the current session.
    var sessionEpisodes: [AnxietyEpisode] {
        lock.lock(); defer { lock.unlock() }
        return _completedEpisodes
    }

    /// Clears completed episode history (called at session end after reporting).
    func clearCompletedEpisodes() {
        lock.lock()
        _completedEpisodes.removeAll()
        lock.unlock()
    }

    // MARK: - Sensitivity Update

    /// Updates sensitivity from user preferences. Called when settings change.
    func updateSensitivity(from preferences: UserPreferences) {
        sensitivityMultiplier = preferences.anxietyInterceptionSensitivity
        logDebug(
            "AnxietyDetector sensitivity updated: \(String(format: "%.2f", preferences.anxietyInterceptionSensitivity))",
            category: .stateEngine
        )
    }

    // MARK: - Reset

    /// Resets the detector to initial state. Used for testing or session restart.
    func reset() {
        lock.lock()
        _currentLevel = .calm
        _currentScore = 0.0
        _activeEpisode = nil
        _completedEpisodes.removeAll()
        _biometricTimeline.removeAll()
        candidateLevelHistory.removeAll()
        lastLevelChangeTimestamp = nil
        committedLevel = .calm
        recentHRVReadings.removeAll()
        baselineWristTemperature = nil
        recentMotionReadings.removeAll()
        lock.unlock()

        logInfo("AnxietyDetector reset", category: .stateEngine)
    }

    // MARK: - Utilities

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}

#endif
