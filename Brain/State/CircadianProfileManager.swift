//
//  CircadianProfileManager.swift
//  Resonance
//
//  Manages the user's learned circadian profile. Queries 21 days of HealthKit
//  hourly statistics (HR, HRV, steps, active energy), derives landmarks
//  (wake/sleep/peak/trough hours), and persists the result to UserDefaults.
//
//  Follows the PersonalBaseline.swift pattern: NSLock for thread safety,
//  UserDefaults persistence via app group, daily refresh cadence.
//

import Foundation

// MARK: - Circadian Profile Manager

/// Builds, caches, and persists a CircadianProfile from HealthKit data.
/// Thread-safe via NSLock, matching the PersonalBaseline pattern.
///
/// The core class and read accessors are available cross-platform (used by
/// SharedStateEngine). HealthKit-dependent methods (buildProfile,
/// refreshProfileIfNeeded) are conditionally compiled for iOS only.
final class CircadianProfileManager {

    // MARK: - Persistence Keys

    private enum Keys {
        static let profileData = "\(CircadianConstants.persistenceKeyPrefix).profileData"
        static let lastRefresh = "\(CircadianConstants.persistenceKeyPrefix).lastRefresh"
    }

    // MARK: - State

    /// Lock protecting mutable state accessed from background HealthKit callbacks.
    private let lock = NSLock()

    private var _currentProfile: CircadianProfile?
    private var _lastRefreshDate: Date?

    /// Thread-safe read access to the current circadian profile.
    var currentProfile: CircadianProfile? {
        lock.lock()
        defer { lock.unlock() }
        return _currentProfile
    }

    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
        self._currentProfile = Self.loadProfile(from: defaults)

        if let data = defaults.object(forKey: Keys.lastRefresh) as? TimeInterval {
            self._lastRefreshDate = Date(timeIntervalSince1970: data)
        }

        let profileDesc: String
        if let profile = _currentProfile {
            profileDesc = "days=\(profile.daysOfData), confidence=\(String(format: "%.2f", profile.confidence))"
        } else {
            profileDesc = "none"
        }
        logDebug("CircadianProfileManager loaded: \(profileDesc)", category: .stateEngine)
    }

    // MARK: - Persistence

    /// Saves the current profile to UserDefaults as JSON.
    private func persist() {
        lock.lock()
        let profile = _currentProfile
        let lastRefresh = _lastRefreshDate
        lock.unlock()

        if let profile = profile {
            do {
                let data = try JSONEncoder().encode(profile)
                defaults.set(data, forKey: Keys.profileData)
            } catch {
                logWarning("Failed to encode circadian profile: \(error.localizedDescription)", category: .stateEngine)
            }
        }

        if let lastRefresh = lastRefresh {
            defaults.set(lastRefresh.timeIntervalSince1970, forKey: Keys.lastRefresh)
        }
    }

    /// Loads a previously persisted profile from UserDefaults.
    private static func loadProfile(from defaults: UserDefaults) -> CircadianProfile? {
        guard let data = defaults.data(forKey: Keys.profileData) else { return nil }
        do {
            return try JSONDecoder().decode(CircadianProfile.self, from: data)
        } catch {
            logWarning("Failed to decode circadian profile: \(error.localizedDescription)", category: .stateEngine)
            return nil
        }
    }

    /// Resets the circadian profile and clears persisted data.
    func reset() {
        lock.lock()
        _currentProfile = nil
        _lastRefreshDate = nil
        lock.unlock()

        defaults.removeObject(forKey: Keys.profileData)
        defaults.removeObject(forKey: Keys.lastRefresh)

        logInfo("CircadianProfileManager reset", category: .stateEngine)
    }

    // MARK: - HealthKit Profile Building (iOS only)

    #if os(iOS)

    /// Triggers a profile rebuild if the cached profile is stale (older than 24 hours)
    /// or missing. Call once per StateEngine start and periodically thereafter.
    func refreshProfileIfNeeded(using healthKit: HealthKitService) {
        lock.lock()
        let lastRefresh = _lastRefreshDate
        lock.unlock()

        let needsRefresh: Bool
        if let lastRefresh = lastRefresh {
            needsRefresh = Date().timeIntervalSince(lastRefresh) > CircadianConstants.profileMaxAgeSeconds
        } else {
            needsRefresh = true
        }

        guard needsRefresh else { return }

        Task {
            await buildProfile(using: healthKit)
        }
    }

    /// Queries HealthKit for hourly statistics over the analysis window and builds
    /// a CircadianProfile. Runs asynchronously; updates the cached profile on completion.
    func buildProfile(using healthKit: HealthKitService) async {
        logInfo("Building circadian profile from HealthKit data", category: .stateEngine)

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(
            byAdding: .day,
            value: -CircadianConstants.analysisWindowDays,
            to: now
        ) else {
            logWarning("Could not compute circadian analysis start date", category: .stateEngine)
            return
        }

        do {
            // Fetch hourly statistics for all signal types in parallel
            async let hrStats = healthKit.fetchHourlyStatistics(
                type: .heartRate,
                from: startDate,
                to: now,
                options: .discreteAverage
            )
            async let hrvStats = healthKit.fetchHourlyStatistics(
                type: .heartRateVariabilitySDNN,
                from: startDate,
                to: now,
                options: .discreteAverage
            )
            async let stepStats = healthKit.fetchHourlyStepCounts(
                from: startDate,
                to: now
            )
            async let energyStats = healthKit.fetchHourlyStatistics(
                type: .activeEnergyBurned,
                from: startDate,
                to: now,
                options: .cumulativeSum
            )

            let hr = try await hrStats
            let hrv = try await hrvStats
            let steps = try await stepStats
            let energy = try await energyStats

            // Build hourly arrays (24 entries)
            var hourlyHR = [Double?](repeating: nil, count: 24)
            var hourlyHRV = [Double?](repeating: nil, count: 24)
            var hourlySteps = [Double?](repeating: nil, count: 24)
            var hourlyEnergy = [Double?](repeating: nil, count: 24)
            var hourlyCounts = [Int](repeating: 0, count: 24)

            for hour in 0..<24 {
                if let stat = hr[hour] {
                    hourlyHR[hour] = stat.average
                    hourlyCounts[hour] = max(hourlyCounts[hour], stat.count)
                }
                if let stat = hrv[hour] {
                    hourlyHRV[hour] = stat.average
                }
                if let stat = steps[hour] {
                    hourlySteps[hour] = stat.average
                    hourlyCounts[hour] = max(hourlyCounts[hour], stat.count)
                }
                if let stat = energy[hour] {
                    hourlyEnergy[hour] = stat.average
                }
            }

            // Derive landmarks
            let wakeHour = Self.deriveWakeHour(hourlyHR: hourlyHR, hourlySteps: hourlySteps)
            let sleepHour = Self.deriveSleepHour(hourlyHR: hourlyHR, hourlySteps: hourlySteps, wakeHour: wakeHour)
            let peakHour = Self.derivePeakEnergyHour(hourlyHR: hourlyHR, hourlySteps: hourlySteps)
            let troughHour = Self.deriveTroughEnergyHour(
                hourlyHR: hourlyHR, hourlySteps: hourlySteps,
                wakeHour: wakeHour, sleepHour: sleepHour
            )

            // Calculate days of data from sample counts
            let daysWithData = Self.calculateDaysOfData(hourlyCounts: hourlyCounts)

            let profile = CircadianProfile(
                hourlyHeartRate: hourlyHR,
                hourlyHRV: hourlyHRV,
                hourlySteps: hourlySteps,
                hourlyActiveEnergy: hourlyEnergy,
                hourlySampleCounts: hourlyCounts,
                typicalWakeHour: wakeHour,
                typicalSleepHour: sleepHour,
                peakEnergyHour: peakHour,
                troughEnergyHour: troughHour,
                computedAt: now,
                daysOfData: daysWithData
            )

            lock.lock()
            _currentProfile = profile
            _lastRefreshDate = now
            lock.unlock()

            persist()

            logInfo(
                "Circadian profile built: wake=\(wakeHour):00, sleep=\(sleepHour):00, "
                + "peak=\(peakHour):00, trough=\(troughHour):00, "
                + "days=\(daysWithData), confidence=\(String(format: "%.2f", profile.confidence))",
                category: .stateEngine
            )
        } catch {
            logWarning(
                "Failed to build circadian profile: \(error.localizedDescription)",
                category: .stateEngine
            )
        }
    }

    #endif

    // MARK: - Landmark Derivation (static helpers, available cross-platform)

    /// Determines the typical wake hour: first hour where HR rises >10% above
    /// overnight minimum AND steps exceed the wake threshold.
    static func deriveWakeHour(hourlyHR: [Double?], hourlySteps: [Double?]) -> Int {
        // Find overnight minimum HR (hours 0-5 as seed)
        let overnightHRs = (0..<6).compactMap { hourlyHR[$0] }
        guard let overnightMin = overnightHRs.min(), overnightMin > 0 else {
            return 7 // Default fallback
        }

        let riseThreshold = overnightMin * (1.0 + CircadianConstants.wakeHRRiseThreshold)

        // Scan from hour 4 to hour 12 for wake signal
        for hour in 4..<12 {
            let hr = hourlyHR[hour] ?? 0
            let steps = hourlySteps[hour] ?? 0
            if hr > riseThreshold && steps > CircadianConstants.wakeStepThreshold {
                return hour
            }
        }

        return 7 // Default if no clear signal
    }

    /// Determines the typical sleep hour: last hour with significant activity
    /// before HR drops toward overnight levels.
    static func deriveSleepHour(hourlyHR: [Double?], hourlySteps: [Double?], wakeHour: Int) -> Int {
        // Find the average HR during active hours
        let activeHRs = (wakeHour..<min(wakeHour + 12, 24)).compactMap { hourlyHR[$0] }
        guard let avgActiveHR = activeHRs.isEmpty ? nil : activeHRs.reduce(0, +) / Double(activeHRs.count) else {
            return 23 // Default fallback
        }

        let dropThreshold = avgActiveHR * 0.90

        // Scan from hour 23 backward to hour 18 for sleep onset
        for hour in stride(from: 23, through: 18, by: -1) {
            let hr = hourlyHR[hour] ?? 0
            let steps = hourlySteps[hour] ?? 0
            if hr > dropThreshold || steps > CircadianConstants.wakeStepThreshold {
                return min(hour + 1, 23)
            }
        }

        return 23 // Default if no clear signal
    }

    /// Finds the hour with the highest combined HR + steps (normalized).
    static func derivePeakEnergyHour(hourlyHR: [Double?], hourlySteps: [Double?]) -> Int {
        let hrs = hourlyHR.map { $0 ?? 0 }
        let steps = hourlySteps.map { $0 ?? 0 }
        let maxHR = hrs.max() ?? 1.0
        let maxSteps = steps.max() ?? 1.0

        guard maxHR > 0, maxSteps > 0 else { return 10 }

        var bestHour = 10
        var bestScore = -1.0
        for hour in 0..<24 {
            let score = (hrs[hour] / maxHR) * 0.5 + (steps[hour] / maxSteps) * 0.5
            if score > bestScore {
                bestScore = score
                bestHour = hour
            }
        }
        return bestHour
    }

    /// Finds the hour of lowest energy during waking hours.
    static func deriveTroughEnergyHour(
        hourlyHR: [Double?],
        hourlySteps: [Double?],
        wakeHour: Int,
        sleepHour: Int
    ) -> Int {
        // Only search waking hours
        let searchStart = wakeHour + 2  // Skip first 2 hours after waking
        let searchEnd = sleepHour

        guard searchStart < searchEnd else { return 14 }

        var bestHour = 14
        var bestScore = Double.greatestFiniteMagnitude
        for hour in searchStart..<searchEnd {
            let hrVal = hourlyHR[hour] ?? 0
            let stepVal = hourlySteps[hour] ?? 0
            // Lower score = lower energy
            let score = hrVal + stepVal
            if score < bestScore && (hourlyHR[hour] != nil || hourlySteps[hour] != nil) {
                bestScore = score
                bestHour = hour
            }
        }
        return bestHour
    }

    /// Estimates the number of distinct days with data by looking at total sample counts.
    static func calculateDaysOfData(hourlyCounts: [Int]) -> Int {
        let totalSamples = hourlyCounts.reduce(0, +)
        let coveredHours = hourlyCounts.filter { $0 > 0 }.count
        guard coveredHours > 0 else { return 0 }
        // Heuristic: average samples per covered hour gives rough daily count
        let avgSamplesPerHour = Double(totalSamples) / Double(coveredHours)
        // Each day contributes roughly 1 sample per hour to the average
        return max(1, min(CircadianConstants.analysisWindowDays, Int(avgSamplesPerHour)))
    }
}
