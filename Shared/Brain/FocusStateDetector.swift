//
//  FocusStateDetector.swift
//  Resonance
//
//  Detects focus and distraction states from HRV (RMSSD) signals for E1
//  ADHD/Neurodivergent Focus Mode. Uses a rolling 20-sample RMSSD buffer
//  and coefficient-of-variation analysis over 6-sample windows to classify
//  focus level and detect distraction events.
//
//  Deep focus requires RMSSD 40-65ms with CV < 0.15 sustained for 3 min.
//  Distraction is flagged when CV > 0.25, RMSSD drops > 15ms from the
//  trailing average, or RMSSD falls outside the 35-85ms attentional range.
//
//  Research: Luque-Casado et al., Psychophysiology 2016;
//            Thayer & Lane, Neuroscience & Biobehavioral Reviews 2009;
//            Luft et al., 2009 (mind-wandering and high RMSSD)
//

#if os(iOS) || os(watchOS)

import Foundation

// MARK: - ADHD Focus Constants

/// All thresholds and configuration values for the ADHD Focus Mode.
public enum ADHDFocusConstants {
    /// RMSSD range indicating deep focus state (ms)
    public static let deepFocusRMSSDRange: ClosedRange<Double> = 40...65

    /// RMSSD range indicating light focus (ms)
    public static let lightFocusRMSSDRange: ClosedRange<Double> = 35...80

    /// CV threshold for deep focus classification
    public static let deepFocusCVThreshold: Double = 0.15

    /// CV threshold above which distraction is detected
    public static let distractionCVThreshold: Double = 0.25

    /// RMSSD sudden drop threshold for distraction detection (ms)
    public static let distractionDropThreshold: Double = 15.0

    /// Minimum RMSSD below which distraction is flagged (chronic stress)
    public static let distractionFloorRMSSD: Double = 35.0

    /// Maximum RMSSD above which distraction is flagged (under-arousal)
    public static let distractionCeilingRMSSD: Double = 85.0

    /// Minimum duration for a focus streak to register (seconds)
    public static let minimumStreakDuration: TimeInterval = 180

    /// Number of RMSSD samples for CV calculation (at 30s intervals = 3 min)
    public static let cvWindowSize: Int = 6

    /// Maximum RMSSD samples to retain for analysis (~10 min at 30s)
    public static let maxRMSSDSamples: Int = 20

    /// Number of trailing samples for average computation
    public static let trailingAverageSize: Int = 3

    /// ADHD Pomodoro focus block duration (seconds)
    public static let focusBlockDuration: Int = 25 * 60

    /// ADHD Pomodoro break duration (seconds)
    public static let breakDuration: Int = 5 * 60

    /// Distraction recovery weight overrides
    public static let distractionFamiliarityWeight: Double = 0.40
    public static let distractionHistoricalWeight: Double = 0.35
    public static let distractionContextWeight: Double = 0.20
    public static let distractionBPMWeight: Double = 0.02
    public static let distractionEnergyWeight: Double = 0.03
}

// MARK: - FocusLevel

/// Discrete focus level derived from HRV patterns.
public enum FocusLevel: String, Codable, Sendable {
    /// Deep focus -- sustained moderate RMSSD with very low variability
    case deepFocus
    /// Light focus -- moderate RMSSD, some fluctuation
    case lightFocus
    /// Distracted -- RMSSD drop, high variability, or out-of-range
    case distracted
    /// Unknown -- insufficient data
    case unknown

    public var displayName: String {
        switch self {
        case .deepFocus: return "Deep Focus"
        case .lightFocus: return "Light Focus"
        case .distracted: return "Distracted"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - FocusStreak

/// A contiguous period of sustained focus.
public struct FocusStreak: Sendable, Identifiable {
    public let id: UUID
    public let startTime: Date
    public var endTime: Date?
    public var peakRMSSD: Double
    public var avgRMSSD: Double
    public var distractionCount: Int
    public var pomodoroBlockIndex: Int?

    /// Duration in seconds. If ongoing, uses current time.
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Duration in minutes.
    public var durationMinutes: Double {
        duration / 60.0
    }

    /// Whether this streak meets the minimum duration threshold.
    public var meetsMinimumDuration: Bool {
        duration >= ADHDFocusConstants.minimumStreakDuration
    }

    public init(
        startTime: Date,
        endTime: Date? = nil,
        peakRMSSD: Double = 0,
        avgRMSSD: Double = 0,
        distractionCount: Int = 0,
        pomodoroBlockIndex: Int? = nil
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.peakRMSSD = peakRMSSD
        self.avgRMSSD = avgRMSSD
        self.distractionCount = distractionCount
        self.pomodoroBlockIndex = pomodoroBlockIndex
    }
}

// MARK: - FocusStateDetector

/// Detects focus/distraction from a stream of RMSSD (HRV) samples.
/// Thread-safe via NSLock -- callers may invoke from any thread.
public final class FocusStateDetector: @unchecked Sendable {

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - Rolling Buffer State

    /// Last N RMSSD samples (up to maxRMSSDSamples).
    private var _recentRMSSD: [Double] = []

    /// Timestamps corresponding to each RMSSD sample.
    private var _timestamps: [Date] = []

    // MARK: - Focus State

    /// Current classified focus level.
    private var _currentLevel: FocusLevel = .unknown

    /// Timestamp when the current level was first established.
    private var _currentLevelStartTime: Date?

    // MARK: - Streak Tracking

    /// The currently active focus streak (nil if not in focus).
    private var _currentStreak: FocusStreak?

    /// All completed streaks that met the minimum duration threshold.
    private var _completedStreaks: [FocusStreak] = []

    /// Running sum of RMSSD values within the current streak for avg computation.
    private var _streakRMSSDSum: Double = 0

    /// Count of RMSSD samples within the current streak.
    private var _streakSampleCount: Int = 0

    // MARK: - Distraction Tracking

    /// Timestamp of the most recent distraction detection.
    private var _lastDistractionTime: Date?

    /// Callback invoked when a distraction event is detected.
    private var _distractionCallback: (() -> Void)?

    /// Current Pomodoro block index for streak tagging.
    private var _currentPomodoroBlock: Int?

    // MARK: - Public Accessors

    /// The current assessed focus level.
    public var currentFocusLevel: FocusLevel {
        lock.withLock { _currentLevel }
    }

    /// The currently active focus streak, if any.
    public var currentStreak: FocusStreak? {
        lock.withLock { _currentStreak }
    }

    /// All completed focus streaks that met the minimum duration.
    public var completedStreaks: [FocusStreak] {
        lock.withLock { _completedStreaks }
    }

    /// Timestamp of the most recent distraction detection.
    public var lastDistractionTimestamp: Date? {
        lock.withLock { _lastDistractionTime }
    }

    /// Total focus minutes across all completed streaks plus current.
    public var totalFocusMinutesToday: Double {
        lock.withLock {
            let completedMinutes = _completedStreaks.reduce(0.0) { $0 + $1.durationMinutes }
            let currentMinutes = _currentStreak?.durationMinutes ?? 0
            return completedMinutes + currentMinutes
        }
    }

    /// Duration of the longest completed streak in minutes.
    public var longestStreakMinutes: Double {
        lock.withLock {
            let completedMax = _completedStreaks.map(\.durationMinutes).max() ?? 0
            let currentDuration = _currentStreak?.durationMinutes ?? 0
            return max(completedMax, currentDuration)
        }
    }

    /// Total number of distraction recoveries across all streaks.
    public var totalRecoveryCount: Int {
        lock.withLock {
            let completedCount = _completedStreaks.reduce(0) { $0 + $1.distractionCount }
            let currentCount = _currentStreak?.distractionCount ?? 0
            return completedCount + currentCount
        }
    }

    // MARK: - Public API

    /// Updates the detector with a new RMSSD sample.
    /// Should be called each time a new HRV reading is available (~30s intervals).
    /// - Returns: The newly classified focus level.
    @discardableResult
    public func update(rmssd: Double, timestamp: Date) -> FocusLevel {
        lock.withLock {
            _appendSample(rmssd, timestamp: timestamp)

            let previousLevel = _currentLevel
            let newLevel = _classifyFocusLevel(timestamp: timestamp)
            _currentLevel = newLevel

            // Handle state transitions
            _handleLevelTransition(
                from: previousLevel,
                to: newLevel,
                rmssd: rmssd,
                timestamp: timestamp
            )

            return newLevel
        }
    }

    /// Registers a callback that fires when a distraction event is detected.
    public func setDistractionCallback(_ callback: @escaping () -> Void) {
        lock.withLock {
            _distractionCallback = callback
        }
    }

    /// Clears the distraction callback.
    public func clearDistractionCallback() {
        lock.withLock {
            _distractionCallback = nil
        }
    }

    /// Sets the current Pomodoro block index for streak tagging.
    public func setPomodoroBlock(_ index: Int?) {
        lock.withLock {
            _currentPomodoroBlock = index
            _currentStreak?.pomodoroBlockIndex = index
        }
    }

    /// Resets all state. Call when ending an ADHD Focus session.
    public func reset() {
        lock.withLock {
            _recentRMSSD.removeAll()
            _timestamps.removeAll()
            _currentLevel = .unknown
            _currentLevelStartTime = nil
            _currentStreak = nil
            _completedStreaks.removeAll()
            _streakRMSSDSum = 0
            _streakSampleCount = 0
            _lastDistractionTime = nil
            _currentPomodoroBlock = nil
        }
    }

    // MARK: - Private: Buffer Management

    /// Appends a sample to the rolling buffer, trimming to max size.
    private func _appendSample(_ rmssd: Double, timestamp: Date) {
        _recentRMSSD.append(rmssd)
        _timestamps.append(timestamp)
        if _recentRMSSD.count > ADHDFocusConstants.maxRMSSDSamples {
            _recentRMSSD.removeFirst()
            _timestamps.removeFirst()
        }
    }

    // MARK: - Private: Classification

    /// Classifies focus level from the RMSSD window statistics.
    private func _classifyFocusLevel(timestamp: Date) -> FocusLevel {
        let count = _recentRMSSD.count
        guard count >= ADHDFocusConstants.trailingAverageSize else { return .unknown }

        let current = _recentRMSSD[count - 1]

        // Check absolute RMSSD bounds (outside attentional range)
        if current < ADHDFocusConstants.distractionFloorRMSSD {
            return .distracted
        }
        if current > ADHDFocusConstants.distractionCeilingRMSSD {
            return .distracted
        }

        // Compute RMSSD drop from trailing average
        let trailingSize = min(ADHDFocusConstants.trailingAverageSize, count - 1)
        if trailingSize > 0 {
            let trailingSlice = _recentRMSSD[(count - 1 - trailingSize)..<(count - 1)]
            let trailingAvg = trailingSlice.reduce(0, +) / Double(trailingSize)
            let drop = trailingAvg - current
            if drop >= ADHDFocusConstants.distractionDropThreshold {
                return .distracted
            }
        }

        // Compute CV over recent cvWindowSize samples
        let cvSampleCount = min(ADHDFocusConstants.cvWindowSize, count)
        let cvSlice = Array(_recentRMSSD.suffix(cvSampleCount))
        let cv = _coefficientOfVariation(cvSlice)

        // High CV indicates sympathetic activation / attentional disruption
        if cv > ADHDFocusConstants.distractionCVThreshold {
            return .distracted
        }

        // Deep focus: RMSSD in optimal range + low CV + sustained duration
        let inDeepRange = ADHDFocusConstants.deepFocusRMSSDRange.contains(current)
        let lowCV = cv < ADHDFocusConstants.deepFocusCVThreshold

        if inDeepRange && lowCV {
            // Check sustained duration (must have been in focus-compatible state for 3+ min)
            if let startTime = _currentLevelStartTime,
               (_currentLevel == .deepFocus || _currentLevel == .lightFocus),
               timestamp.timeIntervalSince(startTime) >= ADHDFocusConstants.minimumStreakDuration {
                return .deepFocus
            }
            // Not yet sustained long enough -- classify as light
            if _currentLevel == .deepFocus {
                // Already deep, stay deep
                return .deepFocus
            }
            return .lightFocus
        }

        // Light focus: in broader acceptable range with moderate CV
        let inLightRange = ADHDFocusConstants.lightFocusRMSSDRange.contains(current)
        if inLightRange && cv <= ADHDFocusConstants.distractionCVThreshold {
            return .lightFocus
        }

        return .lightFocus
    }

    /// Computes coefficient of variation (stddev / mean) for a sample array.
    private func _coefficientOfVariation(_ samples: [Double]) -> Double {
        guard samples.count >= 2 else { return 0 }
        let mean = samples.reduce(0, +) / Double(samples.count)
        guard mean > 0 else { return 1.0 }
        let variance = samples.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
            / Double(samples.count)
        let stdDev = sqrt(variance)
        return stdDev / mean
    }

    // MARK: - Private: State Transitions & Streak Management

    /// Handles transitions between focus levels, managing streaks and callbacks.
    private func _handleLevelTransition(
        from previousLevel: FocusLevel,
        to newLevel: FocusLevel,
        rmssd: Double,
        timestamp: Date
    ) {
        // Track when the current level started
        if newLevel != previousLevel {
            _currentLevelStartTime = timestamp

            #if DEBUG
            logDebug(
                "FocusStateDetector: level changed "
                + "\(previousLevel.rawValue) -> \(newLevel.rawValue), "
                + "rmssd=\(String(format: "%.1f", rmssd)), "
                + "cv=\(String(format: "%.3f", _currentCV)), "
                + "windowSize=\(_recentRMSSD.count)",
                category: .stateEngine
            )
            #endif
        }

        // Update streak tracking based on level
        switch newLevel {
        case .deepFocus, .lightFocus:
            _updateFocusStreak(rmssd: rmssd, timestamp: timestamp)

        case .distracted:
            if previousLevel == .deepFocus || previousLevel == .lightFocus {
                // Transition from focus to distracted -- end streak
                _endCurrentStreak(timestamp: timestamp)
                _lastDistractionTime = timestamp

                // Fire distraction callback outside of main classification
                let callback = _distractionCallback
                // Dispatch to avoid holding the lock during callback execution
                if let callback = callback {
                    DispatchQueue.global(qos: .userInitiated).async {
                        callback()
                    }
                }
            } else if previousLevel == .distracted {
                // Still distracted -- update distraction time
                _lastDistractionTime = timestamp
            }

        case .unknown:
            break
        }
    }

    /// Updates or starts a focus streak with the current RMSSD sample.
    private func _updateFocusStreak(rmssd: Double, timestamp: Date) {
        if _currentStreak != nil {
            // Update running stats
            _streakRMSSDSum += rmssd
            _streakSampleCount += 1
            _currentStreak?.avgRMSSD = _streakRMSSDSum / Double(_streakSampleCount)
            if rmssd > (_currentStreak?.peakRMSSD ?? 0) {
                _currentStreak?.peakRMSSD = rmssd
            }
        } else {
            // Start a new streak
            _currentStreak = FocusStreak(
                startTime: timestamp,
                peakRMSSD: rmssd,
                avgRMSSD: rmssd,
                pomodoroBlockIndex: _currentPomodoroBlock
            )
            _streakRMSSDSum = rmssd
            _streakSampleCount = 1
        }
    }

    /// Ends the current streak and archives it if it meets minimum duration.
    private func _endCurrentStreak(timestamp: Date) {
        guard var streak = _currentStreak else { return }

        streak.endTime = timestamp

        if streak.meetsMinimumDuration {
            _completedStreaks.append(streak)
        }

        _currentStreak = nil
        _streakRMSSDSum = 0
        _streakSampleCount = 0
    }

    /// Current CV for logging purposes.
    private var _currentCV: Double {
        let count = _recentRMSSD.count
        let cvSampleCount = min(ADHDFocusConstants.cvWindowSize, count)
        guard cvSampleCount >= 2 else { return 0 }
        let cvSlice = Array(_recentRMSSD.suffix(cvSampleCount))
        return _coefficientOfVariation(cvSlice)
    }
}

#endif
