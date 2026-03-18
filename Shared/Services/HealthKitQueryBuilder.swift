//
//  HealthKitQueryBuilder.swift
//  Resonance
//
//  Generic query helpers for HealthKitService: sample fetching, category sample
//  fetching, predicate builders, and query lifecycle tracking.
//  Extracted from HealthKitService.swift to keep files under the 500-line limit.
//

#if os(iOS)

import Foundation
import HealthKit

// MARK: - Query Helpers

extension HealthKitService {

    // MARK: - Query Tracking

    func trackQuery(_ query: HKQuery) {
        lock.lock()
        defer { lock.unlock() }
        runningQueries.append(query)
    }

    func untrackQuery(_ query: HKQuery) {
        lock.lock()
        defer { lock.unlock() }
        runningQueries.removeAll { $0 === query }
    }

    // MARK: - Generic Sample Fetching

    /// Fetches `HKQuantitySample` results for the given type, predicate, and limit.
    /// Sorts by `startDate` in the requested direction.
    func fetchSamples(
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

    /// Fetches category samples for a given type within the date range.
    func fetchCategorySamples(
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

    // MARK: - Predicate Builders

    /// Builds a predicate for samples recorded in the last `minutes` minutes.
    func recentPredicate(minutes: Int) -> NSPredicate {
        let now = Date()
        let start = now.addingTimeInterval(-Double(minutes) * 60)
        return HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
    }
}

#endif
