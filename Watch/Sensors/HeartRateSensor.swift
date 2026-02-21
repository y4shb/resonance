//
//  HeartRateSensor.swift
//  Resonance Watch
//
//  Monitors live heart rate and HRV via HealthKit anchored queries.
//

import HealthKit
import Combine

// MARK: - HeartRateSensor

final class HeartRateSensor: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var latestHeartRate: Double?
    @Published private(set) var latestHRV: Double?
    @Published private(set) var isActive = false

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?

    // MARK: - Monitoring Control

    /// Starts anchored object queries for heart rate and HRV.
    func startMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else {
            logWarning("HealthKit not available on this device", category: .healthKit)
            return
        }

        guard !isActive else {
            logDebug("HeartRateSensor already monitoring", category: .healthKit)
            return
        }

        isActive = true

        startHeartRateQuery()
        startHRVQuery()
        logInfo("HeartRateSensor monitoring started", category: .healthKit)
    }

    /// Stops all active HealthKit queries.
    func stopMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        if let query = hrvQuery {
            healthStore.stop(query)
            hrvQuery = nil
        }

        isActive = false
        logInfo("HeartRateSensor monitoring stopped", category: .healthKit)
    }

    // MARK: - Private Helpers

    private func startHeartRateQuery() {
        let heartRateType = HKQuantityType(.heartRate)
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())

        // Predicate limiting to samples from the last hour to avoid flooding on first launch.
        let startDate = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            self?.processHeartRateSamples(samples, unit: heartRateUnit, error: error)
        }

        query.updateHandler = { [weak self] _, samples, _, _, error in
            self?.processHeartRateSamples(samples, unit: heartRateUnit, error: error)
        }

        heartRateQuery = query
        healthStore.execute(query)
        logDebug("Heart rate anchored query started", category: .healthKit)
    }

    private func startHRVQuery() {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let hrvUnit = HKUnit.secondUnit(with: .milli)

        let startDate = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            self?.processHRVSamples(samples, unit: hrvUnit, error: error)
        }

        query.updateHandler = { [weak self] _, samples, _, _, error in
            self?.processHRVSamples(samples, unit: hrvUnit, error: error)
        }

        hrvQuery = query
        healthStore.execute(query)
        logDebug("HRV anchored query started", category: .healthKit)
    }

    private func processHeartRateSamples(
        _ samples: [HKSample]?,
        unit: HKUnit,
        error: Error?
    ) {
        if let error = error {
            logError("Heart rate query error", error: error, category: .healthKit)
            return
        }

        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.last else {
            return
        }

        let bpm = latest.quantity.doubleValue(for: unit)
        logDebug("Heart rate sample received: \(bpm) BPM", category: .healthKit)

        DispatchQueue.main.async { [weak self] in
            self?.latestHeartRate = bpm
        }
    }

    private func processHRVSamples(
        _ samples: [HKSample]?,
        unit: HKUnit,
        error: Error?
    ) {
        if let error = error {
            logError("HRV query error", error: error, category: .healthKit)
            return
        }

        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.last else {
            return
        }

        let hrv = latest.quantity.doubleValue(for: unit)
        logDebug("HRV sample received: \(hrv) ms", category: .healthKit)

        DispatchQueue.main.async { [weak self] in
            self?.latestHRV = hrv
        }
    }
}
