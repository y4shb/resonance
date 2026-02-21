//
//  WorkoutDetector.swift
//  Resonance Watch
//
//  Detects active workout sessions by observing HKWorkoutType via
//  HealthKit observer queries and background delivery.
//

import HealthKit

// MARK: - WorkoutDetector

final class WorkoutDetector: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isInWorkout = false
    @Published private(set) var workoutType: String?

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var activeWorkoutQuery: HKSampleQuery?

    // MARK: - Observation Control

    /// Installs an HKObserverQuery that fires whenever a workout sample is written
    /// to HealthKit, then re-queries for the most recent workout to determine
    /// whether the user is currently in an active session.
    func startObserving() {
        guard HKHealthStore.isHealthDataAvailable() else {
            logWarning("HealthKit not available — WorkoutDetector cannot start", category: .healthKit)
            return
        }

        let workoutType = HKObjectType.workoutType()

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }

            if let error = error {
                logError("Workout observer query error", error: error, category: .healthKit)
                return
            }

            logDebug("Workout observer fired — checking active workout", category: .healthKit)
            self?.fetchMostRecentWorkout()
        }

        observerQuery = query
        healthStore.execute(query)

        // Enable background delivery so the query fires even when the app is not
        // in the foreground. On watchOS this has no effect but is harmless.
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
            if let error = error {
                logError("Failed to enable background delivery for workouts", error: error, category: .healthKit)
            } else {
                logDebug("Background delivery for workouts enabled: \(success)", category: .healthKit)
            }
        }

        // Run an initial check immediately so the published state is populated
        // without waiting for the first HealthKit change notification.
        fetchMostRecentWorkout()
        logInfo("WorkoutDetector observation started", category: .healthKit)
    }

    /// Stops the observer query and clears workout state.
    func stopObserving() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }

        DispatchQueue.main.async { [weak self] in
            self?.isInWorkout = false
            self?.workoutType = nil
        }

        logInfo("WorkoutDetector observation stopped", category: .healthKit)
    }

    // MARK: - Private Helpers

    /// Queries for the single most recent workout and determines whether it
    /// started within the last few minutes, indicating it is still active.
    private func fetchMostRecentWorkout() {
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self = self else { return }

            if let error = error {
                logError("Workout sample query failed", error: error, category: .healthKit)
                return
            }

            guard let workout = samples?.first as? HKWorkout else {
                // No workouts found at all.
                DispatchQueue.main.async { [weak self] in
                    self?.isInWorkout = false
                    self?.workoutType = nil
                }
                return
            }

            // A workout is considered "active" if it has no end date, or its
            // end date is within the last 90 seconds (covering any brief lag in
            // HealthKit committing the end timestamp).
            let now = Date()
            let recentThreshold: TimeInterval = 90
            let workoutEnded = workout.endDate < now.addingTimeInterval(-recentThreshold)
            let active = !workoutEnded

            let typeName = self.displayName(for: workout.workoutActivityType)
            logDebug(
                "Most recent workout: \(typeName), active=\(active)",
                category: .healthKit
            )

            DispatchQueue.main.async { [weak self] in
                self?.isInWorkout = active
                self?.workoutType = active ? typeName : nil
            }
        }

        activeWorkoutQuery = query
        healthStore.execute(query)
    }

    /// Maps an HKWorkoutActivityType to a human-readable string for the
    /// BiometricPacket's workoutType field.
    private func displayName(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running:          return "running"
        case .cycling:          return "cycling"
        case .walking:          return "walking"
        case .swimming:         return "swimming"
        case .yoga:             return "yoga"
        case .hiking:           return "hiking"
        case .rowing:           return "rowing"
        case .elliptical:       return "elliptical"
        case .crossTraining:    return "crossTraining"
        case .highIntensityIntervalTraining: return "hiit"
        case .functionalStrengthTraining:    return "strengthTraining"
        case .traditionalStrengthTraining:   return "strengthTraining"
        case .dance:            return "dance"
        case .pilates:          return "pilates"
        case .stairs:           return "stairs"
        case .jumpRope:         return "jumpRope"
        case .skatingSports:    return "skating"
        case .soccer:           return "soccer"
        case .basketball:       return "basketball"
        case .tennis:           return "tennis"
        case .golf:             return "golf"
        case .boxing:           return "boxing"
        case .martialArts:      return "martialArts"
        case .mindAndBody:      return "mindAndBody"
        case .other:            return "other"
        default:                return "workout"
        }
    }
}
