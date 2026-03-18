//
//  HealthKitTypes.swift
//  Resonance
//
//  Protocol definition, error types, and data models for HealthKit integration.
//  Extracted from HealthKitService.swift to keep files under the 500-line limit.
//

#if os(iOS)

import Foundation
import HealthKit

// MARK: - HealthKit Service Protocol

/// Protocol defining the interface for HealthKit biometric data access.
public protocol HealthKitServiceProtocol {
    /// Requests HealthKit read authorization from the user.
    func requestAuthorization() async throws

    /// Whether the user has granted the necessary HealthKit permissions.
    var isAuthorized: Bool { get }

    /// Returns the most recent heart rate sample in BPM, or nil if unavailable.
    func fetchLatestHeartRate() async throws -> Double?

    /// Returns the most recent HRV sample in milliseconds, or nil if unavailable.
    func fetchLatestHRV() async throws -> Double?

    /// Returns heart rate samples recorded within the last `minutes` minutes.
    func fetchRecentHeartRates(minutes: Int) async throws -> [(value: Double, date: Date)]

    /// Returns HRV samples recorded within the last `minutes` minutes.
    func fetchRecentHRV(minutes: Int) async throws -> [(value: Double, date: Date)]

    /// Returns heart rate samples in the given date range.
    func fetchHeartRateHistory(from: Date, to: Date) async throws -> [(value: Double, date: Date)]

    /// Returns HRV samples in the given date range.
    func fetchHRVHistory(from: Date, to: Date) async throws -> [(value: Double, date: Date)]

    /// Enables HealthKit background delivery for heart rate updates.
    func enableBackgroundDelivery() async throws

    /// An AsyncStream that emits new heart rate values as they arrive.
    var heartRateStream: AsyncStream<Double> { get }

    /// Returns the most recent resting heart rate in BPM, or nil if unavailable.
    func fetchRestingHeartRate() async throws -> Double?

    /// Returns sleep analysis sessions in the given date range, filtered for actual sleep stages.
    func fetchSleepAnalysis(from: Date, to: Date) async throws -> [SleepSession]

    /// Returns workout sessions in the given date range.
    func fetchWorkouts(from: Date, to: Date) async throws -> [WorkoutSession]

    /// Returns the most recent VO2 Max sample in mL/kg/min, or nil if unavailable.
    func fetchVO2Max() async throws -> Double?

    /// Returns the average overnight respiratory rate in breaths/min, or nil if unavailable.
    func fetchOvernightRespiratoryRate() async throws -> Double?

    /// Returns irregular heart rhythm notification event dates from the last N days.
    func fetchIrregularHeartRhythmEvents(days: Int) async throws -> [Date]

    /// Starts observing active workout sessions via HKObserverQuery.
    func startWorkoutObservation(handler: @escaping (HKWorkoutActivityType?) -> Void)

    /// Stops the active workout observer query.
    func stopWorkoutObservation()
}

// MARK: - HealthKit Service Errors

/// Errors specific to the HealthKitService.
public enum HealthKitServiceError: LocalizedError {
    case healthDataUnavailable
    case notAuthorized
    case queryFailed(underlying: Error)
    case backgroundDeliveryFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "HealthKit is not available on this device."
        case .notAuthorized:
            return "HealthKit authorization has not been granted. Please allow access in Settings."
        case .queryFailed(let error):
            return "HealthKit query failed: \(error.localizedDescription)"
        case .backgroundDeliveryFailed(let error):
            return "Failed to enable HealthKit background delivery: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sleep & Workout Types

/// Represents a sleep analysis session from HealthKit.
public struct SleepSession {
    let startDate: Date
    let endDate: Date
    let value: HKCategoryValueSleepAnalysis

    /// Duration in hours.
    var durationHours: Double {
        endDate.timeIntervalSince(startDate) / 3600.0
    }

    /// Whether this sample represents deep sleep.
    var isDeepSleep: Bool {
        value == .asleepDeep
    }

    /// Whether this sample represents REM sleep.
    var isREMSleep: Bool {
        value == .asleepREM
    }
}

/// Represents a workout session from HealthKit.
public struct WorkoutSession {
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let totalEnergyBurned: Double  // kcal
    let durationMinutes: Double

    /// Human-readable activity name.
    var activityName: String {
        switch activityType {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .dance: return "Dance"
        case .cooldown: return "Cooldown"
        case .coreTraining: return "Core Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        default: return "Workout"
        }
    }
}

#endif
