//
//  HealthKitService.swift
//  Resonance
//
//  HealthKit service implementation for reading biometric data.
//  Provides heart rate and HRV access, background delivery, and streaming.
//
//  Related files:
//  - HealthKitTypes.swift: Protocol, error types, and data models
//  - HealthKitQueryBuilder.swift: Generic query helpers and tracking
//  - HealthKitService+NewSignals.swift: VO2 Max, respiratory rate, workout observation
//

#if os(iOS)

import Foundation
import HealthKit

// MARK: - HealthKit Service Implementation

/// Concrete implementation of `HealthKitServiceProtocol` using `HKHealthStore`.
public final class HealthKitService: HealthKitServiceProtocol, ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isAuthorized: Bool = false

    // MARK: - Private Properties

    let healthStore = HKHealthStore()

    /// Tracks all running HKQueries so they can be stopped on deinit.
    var runningQueries: [HKQuery] = []

    /// Lock to protect access to runningQueries and heartRateStream initialization.
    let lock = NSLock()

    /// The set of HKSampleType values this service requests read access to.
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let identifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .stepCount,
            .activeEnergyBurned,
            .restingHeartRate,
            .vo2Max,
            .respiratoryRate,
        ]
        for id in identifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        if let irregularRhythmType = HKObjectType.categoryType(
            forIdentifier: .irregularHeartRhythmEvent
        ) {
            types.insert(irregularRhythmType)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    // MARK: - Convenience Type Accessors

    var heartRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRate)!
    }

    var hrvType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    }

    var restingHeartRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    }

    var vo2MaxType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .vo2Max)!
    }

    var respiratoryRateType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
    }

    /// Active workout observer query, if running.
    var workoutObserverQuery: HKObserverQuery?

    // MARK: - Units

    /// BPM unit: count/minute
    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())

    /// HRV unit: milliseconds
    let hrvUnit = HKUnit.secondUnit(with: .milli)

    // MARK: - Heart Rate Stream (thread-safe lazy initialization)

    private var _heartRateStream: AsyncStream<Double>?

    public var heartRateStream: AsyncStream<Double> {
        lock.lock()
        defer { lock.unlock() }

        if let existing = _heartRateStream {
            return existing
        }

        let stream = AsyncStream<Double> { [weak self] continuation in
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

            self.trackQuery(query)
            self.healthStore.execute(query)

            continuation.onTermination = { [weak self] _ in
                logDebug("Heart rate stream terminated — stopping anchored object query", category: .healthKit)
                self?.healthStore.stop(query)
                self?.untrackQuery(query)
            }
        }

        _heartRateStream = stream
        return stream
    }

    // MARK: - Initialization

    public init() {
        logInfo("HealthKitService initializing", category: .healthKit)
    }

    deinit {
        // Stop all running queries to prevent them from continuing after deallocation.
        lock.lock()
        let queries = runningQueries
        runningQueries.removeAll()
        lock.unlock()

        for query in queries {
            healthStore.stop(query)
        }
        logInfo("HealthKitService deallocated — stopped \(queries.count) running queries", category: .healthKit)
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
}

#endif
