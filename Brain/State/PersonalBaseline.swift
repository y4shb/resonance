//
//  PersonalBaseline.swift
//  Resonance
//
//  Tracks a rolling 7-day personal HRV (RMSSD) baseline using an
//  exponential moving average. Replaces the hardcoded 50ms population
//  baseline in StateEngine with a value that adapts to the individual user.
//
//  Persisted to UserDefaults so the baseline survives app restarts.
//

#if os(iOS)

import Foundation

/// Tracks a personal HRV baseline using exponential moving average
/// over a rolling 7-day window.
final class PersonalBaseline {

    // MARK: - Constants

    private enum Keys {
        static let baselineValue = "com.y4sh.resonance.personalBaseline.rmssd"
        static let sampleCount = "com.y4sh.resonance.personalBaseline.sampleCount"
        static let lastUpdated = "com.y4sh.resonance.personalBaseline.lastUpdated"
    }

    /// Population-level fallback when no personal data exists.
    static let populationDefault = 50.0

    /// EMA smoothing factor. Lower values give more weight to history,
    /// producing a stable 7-day-like rolling average.
    /// With ~10 samples/day over 7 days (~70 samples), alpha = 0.02
    /// gives an effective window of ~50 samples.
    private let alpha = 0.02

    /// Minimum number of samples before we trust the personal baseline
    /// over the population default.
    private let minimumSamples = 10

    /// Maximum age (in seconds) before the baseline is considered stale
    /// and begins blending back toward the population default.
    /// 7 days = 604800 seconds.
    private let maxAgeSeconds: TimeInterval = 604_800

    // MARK: - State

    /// Lock protecting mutable state accessed from HealthKit background callbacks.
    private let lock = NSLock()

    private var _baselineValue: Double
    private var _sampleCount: Int
    private var _lastUpdated: Date?

    /// Thread-safe read access to the current baseline value.
    private(set) var baselineValue: Double {
        get { lock.lock(); defer { lock.unlock() }; return _baselineValue }
        set { lock.lock(); _baselineValue = newValue; lock.unlock() }
    }

    /// Thread-safe read access to the sample count.
    private(set) var sampleCount: Int {
        get { lock.lock(); defer { lock.unlock() }; return _sampleCount }
        set { lock.lock(); _sampleCount = newValue; lock.unlock() }
    }

    /// Thread-safe read access to the last updated date.
    private(set) var lastUpdated: Date? {
        get { lock.lock(); defer { lock.unlock() }; return _lastUpdated }
        set { lock.lock(); _lastUpdated = newValue; lock.unlock() }
    }

    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
        self._baselineValue = defaults.double(forKey: Keys.baselineValue)
        self._sampleCount = defaults.integer(forKey: Keys.sampleCount)

        if let interval = defaults.object(forKey: Keys.lastUpdated) as? TimeInterval {
            self._lastUpdated = Date(timeIntervalSince1970: interval)
        } else {
            self._lastUpdated = nil
        }

        // If no stored baseline, start at population default
        if _sampleCount == 0 {
            _baselineValue = Self.populationDefault
        }

        logDebug(
            "PersonalBaseline loaded: value=\(String(format: "%.1f", _baselineValue))ms, "
            + "samples=\(_sampleCount)",
            category: .stateEngine
        )
    }

    // MARK: - Current Baseline

    /// Returns the current effective baseline, blending personal data with
    /// the population default based on sample confidence and staleness.
    var currentBaseline: Double {
        lock.lock()
        let samples = _sampleCount
        let value = _baselineValue
        let lastUpdate = _lastUpdated
        lock.unlock()

        guard samples >= minimumSamples else {
            // Not enough data -- blend toward personal as samples accumulate
            let personalWeight = Double(samples) / Double(minimumSamples)
            return Self.populationDefault * (1.0 - personalWeight) + value * personalWeight
        }

        // Check staleness
        if let last = lastUpdate {
            let age = Date().timeIntervalSince(last)
            if age > maxAgeSeconds {
                // Stale baseline -- blend back toward population default
                let staleFactor = min(1.0, age / (maxAgeSeconds * 2))
                return value * (1.0 - staleFactor) + Self.populationDefault * staleFactor
            }
        }

        return value
    }

    // MARK: - Update

    /// Records a new HRV (RMSSD) observation and updates the baseline via EMA.
    ///
    /// - Parameter hrvValue: The observed HRV in milliseconds. Must be positive.
    func recordObservation(_ hrvValue: Double) {
        guard hrvValue > 0 else { return }

        lock.lock()
        if _sampleCount == 0 {
            // First observation -- seed directly
            _baselineValue = hrvValue
        } else {
            _baselineValue = (1.0 - alpha) * _baselineValue + alpha * hrvValue
        }

        _sampleCount += 1
        _lastUpdated = Date()
        let currentValue = _baselineValue
        let currentCount = _sampleCount
        lock.unlock()

        persist()

        logDebug(
            "PersonalBaseline updated: value=\(String(format: "%.1f", currentValue))ms "
            + "after observation \(String(format: "%.1f", hrvValue))ms (n=\(currentCount))",
            category: .stateEngine
        )
    }

    // MARK: - Persistence

    /// Saves the baseline state to UserDefaults.
    private func persist() {
        lock.lock()
        let value = _baselineValue
        let count = _sampleCount
        let date = _lastUpdated
        lock.unlock()

        defaults.set(value, forKey: Keys.baselineValue)
        defaults.set(count, forKey: Keys.sampleCount)
        if let date = date {
            defaults.set(date.timeIntervalSince1970, forKey: Keys.lastUpdated)
        }
    }

    /// Resets the baseline to population default. Used for testing or
    /// when the user explicitly requests a reset.
    func reset() {
        lock.lock()
        _baselineValue = Self.populationDefault
        _sampleCount = 0
        _lastUpdated = nil
        lock.unlock()

        defaults.removeObject(forKey: Keys.baselineValue)
        defaults.removeObject(forKey: Keys.sampleCount)
        defaults.removeObject(forKey: Keys.lastUpdated)

        logInfo("PersonalBaseline reset to population default", category: .stateEngine)
    }
}

#endif
