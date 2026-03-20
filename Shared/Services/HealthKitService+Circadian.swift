//
//  HealthKitService+Circadian.swift
//  Resonance
//
//  Extension on HealthKitService providing hourly statistics queries for the
//  circadian rhythm personalization system. Uses HKStatisticsCollectionQuery
//  with hourly intervals, then groups results by hour-of-day (0-23) to produce
//  per-hour averages across the analysis window.
//

#if os(iOS)

import Foundation
import HealthKit

// MARK: - Circadian Data Queries

extension HealthKitService {

    /// Fetches hourly statistics for a quantity type over the given date range,
    /// grouped by hour-of-day (0-23). Returns a dictionary mapping each hour
    /// to its average value and sample count.
    ///
    /// Uses `HKStatisticsCollectionQuery` with 1-hour intervals. The statistics
    /// are then bucketed by hour-of-day and averaged across all days in the range.
    ///
    /// - Parameters:
    ///   - type: The HealthKit quantity type identifier (e.g., .heartRate).
    ///   - from: Start of the query window.
    ///   - to: End of the query window.
    ///   - options: Statistics options (e.g., .discreteAverage, .cumulativeSum).
    /// - Returns: Dictionary keyed by hour (0-23) with average value and count.
    func fetchHourlyStatistics(
        type typeIdentifier: HKQuantityTypeIdentifier,
        from startDate: Date,
        to endDate: Date,
        options: HKStatisticsOptions
    ) async throws -> [Int: (average: Double, count: Int)] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
            logWarning("Unknown quantity type: \(typeIdentifier.rawValue)", category: .healthKit)
            return [:]
        }

        let unit = unitForType(typeIdentifier)
        let calendar = Calendar.current

        // Anchor to midnight of the start date
        let anchorComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
        guard let anchorDate = calendar.date(from: anchorComponents) else {
            return [:]
        }

        let interval = DateComponents(hour: 1)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    logError(
                        "Hourly statistics query failed for \(typeIdentifier.rawValue)",
                        error: error,
                        category: .healthKit
                    )
                    continuation.resume(throwing: HealthKitServiceError.queryFailed(underlying: error))
                    return
                }

                guard let statsCollection = results else {
                    continuation.resume(returning: [:])
                    return
                }

                // Accumulate values by hour-of-day
                var hourlyTotals = [Int: (sum: Double, count: Int)]()

                statsCollection.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    let hour = calendar.component(.hour, from: stats.startDate)

                    let value: Double?
                    switch options {
                    case .discreteAverage:
                        value = stats.averageQuantity()?.doubleValue(for: unit)
                    case .cumulativeSum:
                        value = stats.sumQuantity()?.doubleValue(for: unit)
                    default:
                        value = stats.averageQuantity()?.doubleValue(for: unit)
                    }

                    guard let v = value else { return }

                    var existing = hourlyTotals[hour] ?? (sum: 0, count: 0)
                    existing.sum += v
                    existing.count += 1
                    hourlyTotals[hour] = existing
                }

                // Convert accumulated totals to averages
                var result = [Int: (average: Double, count: Int)]()
                for (hour, total) in hourlyTotals where total.count > 0 {
                    result[hour] = (average: total.sum / Double(total.count), count: total.count)
                }

                logDebug(
                    "Hourly stats for \(typeIdentifier.rawValue): \(result.count) hours with data",
                    category: .healthKit
                )
                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    /// Fetches hourly step counts over the given date range, grouped by
    /// hour-of-day (0-23). Step counts use cumulative sum statistics.
    ///
    /// - Parameters:
    ///   - from: Start of the query window.
    ///   - to: End of the query window.
    /// - Returns: Dictionary keyed by hour (0-23) with average step count and sample count.
    func fetchHourlyStepCounts(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [Int: (average: Double, count: Int)] {
        return try await fetchHourlyStatistics(
            type: .stepCount,
            from: startDate,
            to: endDate,
            options: .cumulativeSum
        )
    }

    // MARK: - Unit Resolution

    /// Returns the appropriate HKUnit for a given quantity type identifier.
    private func unitForType(_ typeIdentifier: HKQuantityTypeIdentifier) -> HKUnit {
        switch typeIdentifier {
        case .heartRate, .restingHeartRate:
            return heartRateUnit
        case .heartRateVariabilitySDNN:
            return hrvUnit
        case .stepCount:
            return .count()
        case .activeEnergyBurned:
            return .kilocalorie()
        default:
            return .count()
        }
    }
}

#endif
