//
//  CircadianProfileTypes.swift
//  Resonance
//
//  Data types for the Circadian Rhythm Personalization system.
//  Defines the learned circadian profile built from 21 days of HealthKit data,
//  shift events for detecting schedule changes, and configuration constants.
//

import Foundation

// MARK: - Circadian Profile

/// A learned circadian profile built from hourly HealthKit statistics over
/// a rolling 21-day window. Contains per-hour averages for heart rate, HRV,
/// steps, and active energy, plus derived landmarks (wake, sleep, peak, trough).
public struct CircadianProfile: Codable, Sendable {

    // MARK: - Hourly Averages (24 entries, index 0 = midnight)

    /// Average heart rate per hour of day. nil for hours with no data.
    public let hourlyHeartRate: [Double?]

    /// Average HRV (SDNN, ms) per hour of day. nil for hours with no data.
    public let hourlyHRV: [Double?]

    /// Average step count per hour of day. nil for hours with no data.
    public let hourlySteps: [Double?]

    /// Average active energy burned (kcal) per hour of day. nil for hours with no data.
    public let hourlyActiveEnergy: [Double?]

    /// Number of samples contributing to each hourly bucket.
    public let hourlySampleCounts: [Int]

    // MARK: - Derived Landmarks

    /// Hour when the user typically wakes (HR rises >10% above overnight min + steps > 50).
    public let typicalWakeHour: Int

    /// Hour when the user typically goes to sleep.
    public let typicalSleepHour: Int

    /// Hour of peak energy (highest HR + steps composite).
    public let peakEnergyHour: Int

    /// Hour of lowest energy (post-lunch dip or overnight trough).
    public let troughEnergyHour: Int

    // MARK: - Metadata

    /// When this profile was computed.
    public let computedAt: Date

    /// Number of days of data used to build this profile.
    public let daysOfData: Int

    // MARK: - Computed Properties

    /// Whether the profile has enough data to be considered reliable.
    /// Requires at least 7 days of data.
    public var isMature: Bool {
        daysOfData >= CircadianConstants.minimumDaysForMature
    }

    /// Confidence score (0.0 - 1.0) based on data coverage.
    /// Averages the day coverage ratio and the hourly bucket coverage ratio.
    public var confidence: Double {
        let dayCoverage = min(1.0, Double(daysOfData) / Double(CircadianConstants.analysisWindowDays))
        let coveredHours = hourlySampleCounts.filter { $0 > 0 }.count
        let hourCoverage = Double(coveredHours) / 24.0
        return (dayCoverage + hourCoverage) / 2.0
    }

    // MARK: - Helpers

    /// Returns the average heart rate across overnight hours (typicalSleepHour to typicalWakeHour).
    public var overnightHeartRateAverage: Double? {
        var values: [Double] = []
        var hour = typicalSleepHour
        while hour != typicalWakeHour {
            if let hr = hourlyHeartRate[hour] {
                values.append(hr)
            }
            hour = (hour + 1) % 24
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Returns the average heart rate across all hours that have data.
    public var overallHeartRateAverage: Double? {
        let values = hourlyHeartRate.compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

// MARK: - Circadian Shift Event

/// Represents a detected shift in the user's circadian rhythm,
/// such as from travel, schedule changes, or gradual drift.
public struct CircadianShiftEvent: Codable, Sendable {

    /// When the shift was detected.
    public let detectedAt: Date

    /// Magnitude of the shift in hours (positive = later, negative = earlier).
    public let shiftHours: Double

    /// Probable cause of the shift.
    public let probableCause: ShiftCause

    /// Whether the user has re-stabilized after the shift.
    public var isResolved: Bool

    /// Possible causes for a circadian shift.
    public enum ShiftCause: String, Codable, Sendable {
        case timezone
        case scheduleChange
        case gradualDrift
        case unknown
    }
}

// MARK: - Circadian Constants

/// Configuration constants for the circadian rhythm personalization system.
public enum CircadianConstants {
    /// Number of days of HealthKit data to analyze when building a profile.
    public static let analysisWindowDays: Int = 21

    /// Minimum number of days before the profile is considered mature/reliable.
    public static let minimumDaysForMature: Int = 7

    /// Maximum age (in seconds) of a profile before a refresh is recommended.
    /// 24 hours = 86400 seconds.
    public static let profileMaxAgeSeconds: TimeInterval = 86_400

    /// Heart rate rise threshold (fraction above overnight minimum) to detect wake.
    public static let wakeHRRiseThreshold: Double = 0.10

    /// Minimum step count per hour to confirm wakefulness.
    public static let wakeStepThreshold: Double = 50.0

    /// Maximum circadian energy modifier magnitude applied to the energy calculation.
    public static let maxEnergyModifier: Double = 0.20

    /// Number of hours before typical sleep hour to consider "pre-sleep".
    public static let preSleepLeadHours: Int = 2

    /// Number of hours after typical wake hour to consider "morning".
    public static let morningWindowHours: Int = 2

    /// UserDefaults key prefix for circadian profile persistence.
    public static let persistenceKeyPrefix = "com.y4sh.resonance.circadian"
}
