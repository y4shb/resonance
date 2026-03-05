//
//  WorkoutSessionManager.swift
//  Resonance Watch
//
//  Manages an HKWorkoutSession for high-frequency heart rate streaming.
//  Starting a workout session unlocks near-real-time HR data (every 1-3 seconds)
//  compared to passive monitoring (every 5+ minutes).
//

import Foundation
import HealthKit
import Combine

#if os(watchOS)

@MainActor
final class WorkoutSessionManager: NSObject, ObservableObject {
    // MARK: - Published State

    @Published private(set) var isWorkoutSessionActive = false
    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var latestHeartRate: Double?
    @Published private(set) var latestHRV: Double?

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKAnchoredObjectQuery?

    // MARK: - Publishers

    private let heartRateSubject = PassthroughSubject<Double, Never>()
    var heartRateUpdates: AnyPublisher<Double, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }

    // MARK: - Start Session

    /// Starts a background workout session to unlock high-frequency HR streaming.
    /// Uses a "Other" workout type to avoid interfering with the user's actual workouts.
    func startHighFrequencySession() async throws {
        guard !isWorkoutSessionActive else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .unknown

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()

        session.delegate = self
        builder.delegate = self

        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        workoutSession = session
        workoutBuilder = builder

        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())

        isWorkoutSessionActive = true
        sessionStartTime = Date()

        // Start anchored query for real-time HR
        startHeartRateQuery()

        logInfo("High-frequency workout session started for enhanced HR streaming", category: .healthKit)
    }

    // MARK: - Stop Session

    func stopHighFrequencySession() async {
        guard isWorkoutSessionActive else { return }

        workoutSession?.end()

        if let builder = workoutBuilder {
            try? await builder.endCollection(at: Date())
            try? await builder.finishWorkout()
        }

        stopHeartRateQuery()

        isWorkoutSessionActive = false
        workoutSession = nil
        workoutBuilder = nil
        sessionStartTime = nil

        logInfo("High-frequency workout session ended", category: .healthKit)
    }

    // MARK: - Heart Rate Query

    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-60),
            end: nil,
            options: .strictStartDate
        )

        var anchor: HKQueryAnchor?

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            anchor = newAnchor
            self?.processHeartRateSamplesFromBackground(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            anchor = newAnchor
            self?.processHeartRateSamplesFromBackground(samples)
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    /// Called from HealthKit's background queue — hops to @MainActor via Task.
    nonisolated private func processHeartRateSamplesFromBackground(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }

        for sample in samples {
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            Task { @MainActor [weak self] in
                self?.latestHeartRate = bpm
                self?.heartRateSubject.send(bpm)
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                logInfo("Workout session running", category: .healthKit)
            case .ended:
                isWorkoutSessionActive = false
                logInfo("Workout session ended", category: .healthKit)
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        logError("Workout session failed", error: error, category: .healthKit)
        Task { @MainActor in
            isWorkoutSessionActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Heart rate data is handled by the anchored object query
    }
}

#endif
