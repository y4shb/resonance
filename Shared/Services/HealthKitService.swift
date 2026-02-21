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

    public var heartRateStream: AsyncStream<Double> {
        AsyncStream<Double> { continuation in
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
                type: heartRateType,
                predicate: predicate,
                anchor: nil,
                limit: HKObjectQueryNoLimit,
                resultsHandler: updateHandler
            )
            query.updateHandler = updateHandler

            healthStore.execute(query)

            continuation.onTermination = { [weak self] _ in
                logDebug("Heart rate stream terminated — stopping anchored object query", category: .healthKit)
                self?.healthStore.stop(query)
            }
        }
    }

    // MARK: - Private Helpers

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
