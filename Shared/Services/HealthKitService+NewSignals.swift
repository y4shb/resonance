//
//  HealthKitService+NewSignals.swift
//  Resonance
//
//  Extension for new biometric signal queries: VO2 Max, respiratory rate,
//  irregular heart rhythm detection, workout observation, and HRV quality.
//  (Workstreams 2.4, 3.1, 3.3, 3.7, 3.8)
//

#if os(iOS)

import Foundation
import HealthKit

// MARK: - New Input Signals (Workstream 3)

extension HealthKitService {

    // MARK: - VO2 Max (Workstream 3.1)

    public func fetchVO2Max() async throws -> Double? {
        logDebug("Fetching VO2 Max", category: .healthKit)

        let vo2MaxUnit = HKUnit(from: "mL/kg*min")
        let samples = try await fetchSamples(
            type: vo2MaxType,
            predicate: nil,
            limit: 1,
            ascending: false
        )
        guard let sample = samples.first else {
            logDebug("No VO2 Max samples found", category: .healthKit)
            return nil
        }
        let value = sample.quantity.doubleValue(for: vo2MaxUnit)
        logDebug("VO2 Max: \(String(format: "%.1f", value)) mL/kg/min", category: .healthKit)
        return value
    }

    // MARK: - Respiratory Rate (Workstream 3.3)

    public func fetchOvernightRespiratoryRate() async throws -> Double? {
        logDebug("Fetching overnight respiratory rate", category: .healthKit)

        // Query respiratory rate samples from last night (10 PM yesterday to 8 AM today)
        let calendar = Calendar.current
        let now = Date()
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)

        guard let today8AM = calendar.date(
            from: DateComponents(
                year: todayComponents.year,
                month: todayComponents.month,
                day: todayComponents.day,
                hour: 8
            )
        ),
        let yesterday10PM = calendar.date(byAdding: .hour, value: -10, to: today8AM) else {
            logDebug("Could not construct overnight date range", category: .healthKit)
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: yesterday10PM,
            end: today8AM,
            options: .strictStartDate
        )

        let breathsPerMinute = HKUnit.count().unitDivided(by: .minute())
        let samples = try await fetchSamples(
            type: respiratoryRateType,
            predicate: predicate,
            limit: HealthKitConstants.historicalQueryLimit,
            ascending: true
        )

        guard !samples.isEmpty else {
            logDebug("No overnight respiratory rate samples found", category: .healthKit)
            return nil
        }

        let totalRate = samples.reduce(0.0) { sum, sample in
            sum + sample.quantity.doubleValue(for: breathsPerMinute)
        }
        let average = totalRate / Double(samples.count)

        logDebug(
            "Overnight respiratory rate: \(String(format: "%.1f", average)) breaths/min "
            + "(\(samples.count) samples)",
            category: .healthKit
        )
        return average
    }

    // MARK: - Irregular Heart Rhythm (Workstream 3.8)

    public func fetchIrregularHeartRhythmEvents(days: Int = 7) async throws -> [Date] {
        logDebug("Fetching irregular heart rhythm events for last \(days) days", category: .healthKit)

        guard let irregularRhythmType = HKCategoryType.categoryType(
            forIdentifier: .irregularHeartRhythmEvent
        ) else {
            logDebug("Irregular heart rhythm event type not available", category: .healthKit)
            return []
        }

        let startDate = Date().addingTimeInterval(-Double(days) * 86400)
        let samples = try await fetchCategorySamples(
            type: irregularRhythmType,
            from: startDate,
            to: Date()
        )

        let eventDates = samples.map { $0.startDate }
        logDebug("Found \(eventDates.count) irregular heart rhythm events", category: .healthKit)
        return eventDates
    }

    // MARK: - Workout Observation (Workstream 3.7)

    public func startWorkoutObservation(
        handler: @escaping (HKWorkoutActivityType?) -> Void
    ) {
        // Stop any existing observer first
        stopWorkoutObservation()

        logInfo("Starting workout observer query", category: .healthKit)

        let query = HKObserverQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: nil
        ) { [weak self] _, completionHandler, error in
            if let error = error {
                logError("Workout observer query error", error: error, category: .healthKit)
                completionHandler()
                return
            }

            // Fetch the most recent active workout
            Task {
                do {
                    let now = Date()
                    let recentStart = now.addingTimeInterval(-3600) // Last hour
                    guard let self = self else {
                        completionHandler()
                        return
                    }
                    let workouts = try await self.fetchWorkouts(from: recentStart, to: now)

                    // Check for a workout that is still ongoing (ended within last 5 min
                    // or end date is very close to now)
                    let activeWorkout = workouts.last { workout in
                        now.timeIntervalSince(workout.endDate) < 300
                    }

                    handler(activeWorkout?.activityType)
                } catch {
                    logError(
                        "Failed to fetch workout in observer",
                        error: error,
                        category: .healthKit
                    )
                    handler(nil)
                }
                completionHandler()
            }
        }

        workoutObserverQuery = query
        trackQuery(query)
        healthStore.execute(query)
    }

    public func stopWorkoutObservation() {
        guard let query = workoutObserverQuery else { return }
        healthStore.stop(query)
        untrackQuery(query)
        workoutObserverQuery = nil
        logInfo("Stopped workout observer query", category: .healthKit)
    }

    // MARK: - HRV Quality Assessment (Workstream 2.4)

    /// Fetches the latest HRV sample along with its quality assessment.
    ///
    /// Checks `HKMetadataKeyHeartRateMotionContext` on the sample to determine
    /// if it was recorded during motion.
    ///
    /// - Returns: Tuple of (hrvValue, hrvQuality) or nil if no samples available.
    public func fetchLatestHRVWithQuality() async throws -> (value: Double, quality: Double)? {
        logDebug("Fetching latest HRV with quality assessment", category: .healthKit)
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

        // Check motion context metadata
        let motionContext: Int?
        if let motionValue = sample.metadata?[
            HKMetadataKeyHeartRateMotionContext
        ] as? NSNumber {
            motionContext = motionValue.intValue
        } else {
            motionContext = nil
        }

        // HKHeartRateMotionContext: 0 = notSet, 1 = sedentary, 2 = active
        let isStationaryFromContext = motionContext == nil || motionContext == 1

        let quality = SensorConfidenceScorer.computeHRVQuality(
            isStationary: isStationaryFromContext,
            isInWorkout: false,
            motionContext: motionContext,
            rrIntervalCV: nil,
            accelerometerMagnitude: 0.0
        )

        logDebug(
            "Latest HRV: \(ms) ms, quality: \(String(format: "%.2f", quality)), "
            + "motionContext: \(motionContext.map(String.init) ?? "nil")",
            category: .healthKit
        )

        return (value: ms, quality: quality)
    }
}

#endif
