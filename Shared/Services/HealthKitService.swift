//
//  HealthKitService.swift
//  Resonance
//
//  HealthKit service protocol and implementation for reading biometric data.
//  Provides heart rate and HRV access, background delivery, and streaming.
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

// MARK: - HealthKit Service Implementation

/// Concrete implementation of `HealthKitServiceProtocol` using `HKHealthStore`.
public final class HealthKitService: HealthKitServiceProtocol, ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isAuthorized: Bool = false

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()

    /// The set of HKSampleType values this service requests read access to.
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let identifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .stepCount,
            .activeEnergyBurned,
            .restingHeartRate,
        ]
        for id in identifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    // MARK: - Convenience Type Accessors

    private var heartRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRate)!
    }

    private var hrvType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    }

    private var restingHeartRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    }

    // MARK: - Units

    /// BPM unit: count/minute
    private let heartRateUnit = HKUnit.count().unitDivided(by: .minute())

    /// HRV unit: milliseconds
    private let hrvUnit = HKUnit.secondUnit(with: .milli)

    // MARK: - Initialization

    public init() {
        logInfo("HealthKitService initializing", category: .healthKit)
    }

    // MARK: - Authorization

    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            logError("HealthKit is not available on this device", category: .healthKit)
            throw HealthKitServiceError.healthDataUnavailable
        }

        logInfo("Requesting HealthKit authorization", category: .healthKit)

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            await MainActor.run {
                // Note: HealthKit does not reveal whether read access was granted.
                // We set this flag to indicate authorization was requested, not necessarily granted.
                self.isAuthorized = true
            }
            logInfo("HealthKit authorization requested (read access status is opaque per Apple policy)", category: .healthKit)
        } catch {
            logError("HealthKit authorization request failed", error: error, category: .healthKit)
            throw error
        }
    }

    // MARK: - Latest Sample Queries

    public func fetchLatestHeartRate() async throws -> Double? {
        logDebug("Fetching latest heart rate", category: .healthKit)
        let samples = try await fetchSamples(
            type: heartRateType,
            predicate: nil,
            limit: 1,
            ascending: false
        )
        guard let sample = samples.first else {
            logDebug("No heart rate samples found", category: .healthKit)
            return nil
        }
        let bpm = sample.quantity.doubleValue(for: heartRateUnit)
        logDebug("Latest heart rate: \(bpm) BPM", category: .healthKit)
        return bpm
    }

    public func fetchLatestHRV() async throws -> Double? {
        logDebug("Fetching latest HRV", category: .healthKit)
        let samples = try await fetchSamples(
            type: hrvType,
            predicate: nil,
            limit: 1,
            ascending: false
        )
        guard let sample = samples.first else {
            logDebug("No HRV samples found", category: .healthKit)
            return nil
        }
        let ms = sample.quantity.doubleValue(for: hrvUnit)
        logDebug("Latest HRV: \(ms) ms", category: .healthKit)
        return ms
    }

    // MARK: - Recent Sample Queries

    public func fetchRecentHeartRates(minutes: Int) async throws -> [(value: Double, date: Date)] {
        logDebug("Fetching heart rates for last \(minutes) minutes", category: .healthKit)
        let predicate = recentPredicate(minutes: minutes)
        let samples = try await fetchSamples(
            type: heartRateType,
            predicate: predicate,
            limit: HealthKitConstants.historicalQueryLimit,
            ascending: true
        )
        let results = samples.map { (value: $0.quantity.doubleValue(for: heartRateUnit), date: $0.startDate) }
        logDebug("Fetched \(results.count) heart rate samples", category: .healthKit)
        return results
    }

    public func fetchRecentHRV(minutes: Int) async throws -> [(value: Double, date: Date)] {
        logDebug("Fetching HRV samples for last \(minutes) minutes", category: .healthKit)
        let predicate = recentPredicate(minutes: minutes)
        let samples = try await fetchSamples(
            type: hrvType,
            predicate: predicate,
            limit: HealthKitConstants.historicalQueryLimit,
            ascending: true
        )
        let results = samples.map { (value: $0.quantity.doubleValue(for: hrvUnit), date: $0.startDate) }
        logDebug("Fetched \(results.count) HRV samples", category: .healthKit)
        return results
    }

    // MARK: - Historical Range Queries

    public func fetchHeartRateHistory(from: Date, to: Date) async throws -> [(value: Double, date: Date)] {
        logDebug("Fetching heart rate history from \(from) to \(to)", category: .healthKit)
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let samples = try await fetchSamples(
            type: heartRateType,
            predicate: predicate,
            limit: HealthKitConstants.historicalQueryLimit,
            ascending: true
        )
        let results = samples.map { (value: $0.quantity.doubleValue(for: heartRateUnit), date: $0.startDate) }
        logDebug("Fetched \(results.count) historical heart rate samples", category: .healthKit)
        return results
    }

    public func fetchHRVHistory(from: Date, to: Date) async throws -> [(value: Double, date: Date)] {
        logDebug("Fetching HRV history from \(from) to \(to)", category: .healthKit)
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let samples = try await fetchSamples(
            type: hrvType,
            predicate: predicate,
            limit: HealthKitConstants.historicalQueryLimit,
            ascending: true
        )
        let results = samples.map { (value: $0.quantity.doubleValue(for: hrvUnit), date: $0.startDate) }
        logDebug("Fetched \(results.count) historical HRV samples", category: .healthKit)
        return results
    }

    // MARK: - Resting Heart Rate

    public func fetchRestingHeartRate() async throws -> Double? {
        logDebug("Fetching resting heart rate", category: .healthKit)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: restingHeartRateType,
                quantitySamplePredicate: nil,
                options: .mostRecent
            ) { _, statistics, error in
                if let error = error {
                    logError("Resting heart rate query failed", error: error, category: .healthKit)
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(underlying: error))
                    return
                }
                guard let quantity = statistics?.mostRecentQuantity() else {
                    logDebug("No resting heart rate data available", category: .healthKit)
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = quantity.doubleValue(for: self.heartRateUnit)
                logDebug("Resting heart rate: \(bpm) BPM", category: .healthKit)
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Background Delivery

    public func enableBackgroundDelivery() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.healthDataUnavailable
        }

        logInfo("Enabling HealthKit background delivery for heart rate", category: .healthKit)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
                if let error = error {
                    logError(
                        "Failed to enable background delivery for heart rate",
                        error: error,
                        category: .healthKit
                    )
                    continuation.resume(throwing: HealthKitServiceError.backgroundDeliveryFailed(underlying: error))
                    return
                }
                if success {
                    logInfo("Background delivery enabled for heart rate", category: .healthKit)
                    continuation.resume()
                } else {
                    let failError = HealthKitServiceError.backgroundDeliveryFailed(
                        underlying: NSError(
                            domain: "HealthKitService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Background delivery returned false without an error"]
                        )
                    )
                    logWarning("Background delivery not enabled (success=false, no error)", category: .healthKit)
                    continuation.resume(throwing: failError)
                }
            }
        }
    }

    // MARK: - Heart Rate Stream

    public lazy var heartRateStream: AsyncStream<Double> = {
        AsyncStream<Double> { [weak self] continuation in
            guard let self = self else {
                continuation.finish()
                return
            }

            logDebug("Starting heart rate AsyncStream via anchored object query", category: .healthKit)

            let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
            updateHandler = { [weak self] _, samples, _, _, error in
                guard let self = self else { return }
                if let error = error {
                    logError("Heart rate stream query error", error: error, category: .healthKit)
                    continuation.finish()
                    return
                }
                guard let quantitySamples = samples as? [HKQuantitySample] else { return }
                for sample in quantitySamples {
                    let bpm = sample.quantity.doubleValue(for: self.heartRateUnit)
                    logDebug("Heart rate stream emitting: \(bpm) BPM", category: .healthKit)
                    continuation.yield(bpm)
                }
            }

            let startDate = Date().addingTimeInterval(-3600) // Last hour
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

            let query = HKAnchoredObjectQuery(
                type: self.heartRateType,
                predicate: predicate,
                anchor: nil,
                limit: HKObjectQueryNoLimit,
                resultsHandler: updateHandler
            )
            query.updateHandler = updateHandler

            self.healthStore.execute(query)

            continuation.onTermination = { [weak self] _ in
                logDebug("Heart rate stream terminated — stopping anchored object query", category: .healthKit)
                self?.healthStore.stop(query)
            }
        }
    }()

    // MARK: - Sleep Analysis

    public func fetchSleepAnalysis(from: Date, to: Date) async throws -> [SleepSession] {
        logDebug("Fetching sleep analysis from \(from) to \(to)", category: .healthKit)

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            logError("Sleep analysis type not available", category: .healthKit)
            return []
        }

        let samples = try await fetchCategorySamples(
            type: sleepType,
            from: from,
            to: to
        )

        // Filter for actual asleep stages only
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]

        let sessions = samples
            .filter { asleepValues.contains($0.value) }
            .compactMap { sample -> SleepSession? in
                guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) else {
                    return nil
                }
                return SleepSession(
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    value: sleepValue
                )
            }
            .sorted { $0.startDate < $1.startDate }

        logDebug("Fetched \(sessions.count) sleep sessions", category: .healthKit)
        return sessions
    }

    // MARK: - Workouts

    public func fetchWorkouts(from: Date, to: Date) async throws -> [WorkoutSession] {
        logDebug("Fetching workouts from \(from) to \(to)", category: .healthKit)

        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate,
                ascending: true
            )
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(underlying: error))
                    return
                }
                let workoutSamples = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workoutSamples)
            }
            healthStore.execute(query)
        }

        let sessions = workouts.map { workout in
            WorkoutSession(
                activityType: workout.workoutActivityType,
                startDate: workout.startDate,
                endDate: workout.endDate,
                totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                durationMinutes: workout.duration / 60.0
            )
        }

        logDebug("Fetched \(sessions.count) workout sessions", category: .healthKit)
        return sessions
    }

    // MARK: - Private Helpers

    /// Fetches category samples for a given type within the date range.
    private func fetchCategorySamples(
        type: HKCategoryType,
        from: Date,
        to: Date,
        limit: Int = HKObjectQueryNoLimit,
        ascending: Bool = true
    ) async throws -> [HKCategorySample] {
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate,
                ascending: ascending
            )
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(underlying: error))
                    return
                }
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples)
            }
            self.healthStore.execute(query)
        }
    }

    /// Fetches `HKQuantitySample` results for the given type, predicate, and limit.
    /// Sorts by `startDate` in the requested direction.
    private func fetchSamples(
        type: HKQuantityType,
        predicate: NSPredicate?,
        limit: Int,
        ascending: Bool
    ) async throws -> [HKQuantitySample] {
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate,
                ascending: ascending
            )
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(underlying: error))
                    return
                }
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: quantitySamples)
            }
            healthStore.execute(query)
        }
    }

    /// Builds a predicate for samples recorded in the last `minutes` minutes.
    private func recentPredicate(minutes: Int) -> NSPredicate {
        let now = Date()
        let start = now.addingTimeInterval(-Double(minutes) * 60)
        return HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
    }
}

#endif
