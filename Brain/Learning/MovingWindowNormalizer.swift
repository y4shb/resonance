//
//  MovingWindowNormalizer.swift
//  Resonance
//
//  Workstream 2.3: Moving-window normalization for biometric reward signals.
//
//  Replaces fixed normalization factors (LearningConstants.hrvNormalizationFactor = 10ms)
//  with personal rolling baselines. A 20% change relative to the user's own baseline
//  is treated as a significant response, regardless of absolute values.
//
//  Formula: normalizedHRV = hrvDelta / (personalHRVBaseline * significantChangeFraction)
//
//  This adapts to users with naturally high or low HRV (e.g., athletes vs. elderly),
//  avoiding the one-size-fits-all 10ms threshold.
//

#if os(iOS)

import Foundation

/// Normalizes biometric deltas relative to a personal rolling baseline
/// instead of fixed population-level constants.
///
/// Integrates with `PersonalBaseline` for the rolling HRV baseline and
/// maintains its own HR baseline for heart rate normalization.
struct MovingWindowNormalizer {

    // MARK: - Constants

    /// Fraction of personal baseline that constitutes a "significant" change.
    /// 0.2 means a 20% change from baseline is a full-magnitude reward signal.
    static let significantChangeFraction = 0.2

    /// Minimum baseline value to prevent division by zero or extreme normalization
    /// when the baseline is very low (e.g., first few samples).
    static let minimumHRVBaseline = 10.0
    static let minimumHRBaseline = 40.0

    // MARK: - HRV Normalization

    /// Normalizes an HRV delta relative to the user's personal baseline.
    ///
    /// - Parameters:
    ///   - hrvDelta: Raw HRV change in milliseconds (positive = relaxation).
    ///   - personalBaseline: User's personal HRV baseline from `PersonalBaseline`.
    /// - Returns: Normalized HRV delta where 1.0 = one "significant" change unit.
    static func normalizeHRV(
        delta hrvDelta: Double,
        personalBaseline: Double
    ) -> Double {
        let effectiveBaseline = max(personalBaseline, minimumHRVBaseline)
        let significantChange = effectiveBaseline * significantChangeFraction
        return hrvDelta / significantChange
    }

    /// Normalizes an HRV delta using the fixed factor as a fallback when no
    /// personal baseline is available. This preserves backward compatibility
    /// with the existing `LearningConstants.hrvNormalizationFactor`.
    ///
    /// - Parameters:
    ///   - hrvDelta: Raw HRV change in milliseconds.
    ///   - personalBaseline: Optional personal baseline. Uses fixed factor when nil.
    /// - Returns: Normalized HRV delta.
    static func normalizeHRVWithFallback(
        delta hrvDelta: Double,
        personalBaseline: Double?
    ) -> Double {
        if let baseline = personalBaseline, baseline > minimumHRVBaseline {
            return normalizeHRV(delta: hrvDelta, personalBaseline: baseline)
        }
        // Fall back to fixed normalization factor
        return hrvDelta / LearningConstants.hrvNormalizationFactor
    }

    // MARK: - HR Normalization

    /// Normalizes a heart rate delta relative to a personal HR baseline.
    ///
    /// - Parameters:
    ///   - hrDelta: Raw HR change in BPM.
    ///   - restingHR: User's resting heart rate (from HealthKit or default).
    /// - Returns: Normalized HR delta where 1.0 = one "significant" change unit.
    static func normalizeHR(
        delta hrDelta: Double,
        restingHR: Double
    ) -> Double {
        let effectiveBaseline = max(restingHR, minimumHRBaseline)
        let significantChange = effectiveBaseline * significantChangeFraction
        return hrDelta / significantChange
    }

    /// Normalizes a heart rate delta with fixed fallback.
    ///
    /// - Parameters:
    ///   - hrDelta: Raw HR change in BPM.
    ///   - restingHR: Optional resting HR. Uses fixed factor when nil.
    /// - Returns: Normalized HR delta.
    static func normalizeHRWithFallback(
        delta hrDelta: Double,
        restingHR: Double?
    ) -> Double {
        if let rhr = restingHR, rhr > minimumHRBaseline {
            return normalizeHR(delta: hrDelta, restingHR: rhr)
        }
        // Fall back to fixed normalization factor
        return hrDelta / LearningConstants.hrNormalizationFactor
    }
}

// MARK: - PersonalBaseline HR Extension

/// Extends PersonalBaseline to also track a rolling HR baseline.
/// This complements the existing HRV baseline tracking.
final class PersonalHRBaseline {

    // MARK: - Constants

    private enum Keys {
        static let baselineValue = "com.y4sh.resonance.personalHRBaseline.value"
        static let sampleCount = "com.y4sh.resonance.personalHRBaseline.sampleCount"
        static let lastUpdated = "com.y4sh.resonance.personalHRBaseline.lastUpdated"
    }

    /// Population-level fallback resting heart rate.
    static let populationDefault = 70.0

    /// EMA smoothing factor for HR baseline.
    private let alpha = 0.02

    /// Minimum samples before trusting the personal baseline.
    private let minimumSamples = 10

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
        }

        if _sampleCount == 0 {
            _baselineValue = Self.populationDefault
        }
    }

    // MARK: - Current Baseline

    /// Returns the current effective HR baseline, blending personal data
    /// with the population default based on sample count.
    var currentBaseline: Double {
        lock.lock()
        let samples = _sampleCount
        let value = _baselineValue
        lock.unlock()

        guard samples >= minimumSamples else {
            let personalWeight = Double(samples) / Double(minimumSamples)
            return Self.populationDefault * (1.0 - personalWeight) + value * personalWeight
        }
        return value
    }

    // MARK: - Update

    /// Records a new resting HR observation.
    func recordObservation(_ hrValue: Double) {
        guard hrValue > 0 else { return }

        lock.lock()
        if _sampleCount == 0 {
            _baselineValue = hrValue
        } else {
            _baselineValue = (1.0 - alpha) * _baselineValue + alpha * hrValue
        }

        _sampleCount += 1
        _lastUpdated = Date()
        lock.unlock()

        persist()
    }

    // MARK: - Persistence

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

    func reset() {
        lock.lock()
        _baselineValue = Self.populationDefault
        _sampleCount = 0
        _lastUpdated = nil
        lock.unlock()

        defaults.removeObject(forKey: Keys.baselineValue)
        defaults.removeObject(forKey: Keys.sampleCount)
        defaults.removeObject(forKey: Keys.lastUpdated)
    }
}

#endif
