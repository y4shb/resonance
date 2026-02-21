//
//  ContextCollector.swift
//  Resonance
//
//  Central collector for all context signals on iPhone.
//  Receives biometric updates from Watch via WatchConnectivityManager,
//  persists BiometricSamples to Core Data, and maintains an aggregated context.
//

#if os(iOS)

import Foundation
import Combine
import CoreData

/// Central collector for all context signals on iPhone.
/// Receives biometric updates from Watch via WatchConnectivityManager,
/// persists BiometricSamples to Core Data, and maintains an aggregated context.
final class ContextCollector: ObservableObject {

    // MARK: - Dependencies

    private let persistence: PersistenceController
    private let watchManager: WatchConnectivityManager

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State

    @Published private(set) var latestBiometric: BiometricSignal?
    @Published private(set) var latestMacOSContext: MacOSContextSignal?
    @Published private(set) var aggregatedContext: AggregatedContext

    // MARK: - Active Event Tracking

    /// Set by the app to tag BiometricSamples with the active playback event.
    var activeEventObjectID: NSManagedObjectID?

    /// Guards against duplicate subscriptions if startCollecting() is called multiple times.
    private var isCollecting = false

    // MARK: - Initialization

    init(
        persistence: PersistenceController = .shared,
        watchManager: WatchConnectivityManager = .shared
    ) {
        self.persistence = persistence
        self.watchManager = watchManager
        self.aggregatedContext = AggregatedContext()
        logInfo("ContextCollector initialized", category: .general)
    }

    /// Starts listening for biometric updates from the Watch.
    func startCollecting() {
        guard !isCollecting else { return }
        isCollecting = true

        watchManager.biometricUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packet in
                self?.handleBiometricUpdate(packet)
            }
            .store(in: &cancellables)

        logInfo("ContextCollector started collecting biometric updates", category: .general)
    }

    /// Subscribes to the EventLogger's active event and propagates the object ID for biometric tagging.
    func observeEventLogger(_ eventLogger: EventLogger) {
        eventLogger.$activeEventObjectID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] objectID in
                self?.activeEventObjectID = objectID
            }
            .store(in: &cancellables)
    }

    // MARK: - Biometric Handling

    private func handleBiometricUpdate(_ packet: BiometricPacket) {
        // 1. Convert BiometricPacket → BiometricSignal
        let signal = BiometricSignal(
            heartRate: packet.heartRate,
            hrv: packet.hrv,
            isStationary: packet.isStationary,
            isInWorkout: packet.isInWorkout,
            workoutType: packet.workoutType,
            sampleQuality: 1.0,
            sourceDevice: "watch"
        )

        // 2. Update in-memory cache
        latestBiometric = signal

        // 3. Persist to Core Data as BiometricSample
        persistBiometricSample(signal)

        // 4. Rebuild aggregated context
        rebuildAggregatedContext()

        logDebug(
            "Biometric update processed: HR=\(packet.heartRate.map { String(format: "%.0f", $0) } ?? "nil"), " +
            "HRV=\(packet.hrv.map { String(format: "%.1f", $0) } ?? "nil")",
            category: .general
        )
    }

    private func persistBiometricSample(_ signal: BiometricSignal) {
        let eventObjectID = self.activeEventObjectID
        persistence.performBackgroundTask { context in
            let sample = NSEntityDescription.insertNewObject(
                forEntityName: "BiometricSample", into: context
            )
            sample.setValue(UUID(), forKey: "id")
            sample.setValue(signal.timestamp, forKey: "timestamp")
            sample.setValue(signal.heartRate ?? 0, forKey: "heartRate")
            sample.setValue(signal.hrv ?? 0, forKey: "heartRateVariability")
            sample.setValue(signal.isStationary, forKey: "isStationary")
            sample.setValue(signal.sourceDevice, forKey: "sourceDevice")
            sample.setValue(signal.sampleQuality, forKey: "sampleQuality")

            var eventUUID: UUID? = nil
            if let oid = eventObjectID,
               let event = try? context.existingObject(with: oid) as? PlaybackEvent {
                eventUUID = event.id
            }
            sample.setValue(eventUUID, forKey: "activePlaybackEventId")

            do {
                try context.save()
            } catch {
                logError("Failed to persist BiometricSample", error: error, category: .persistence)
            }
        }
    }

    private func rebuildAggregatedContext() {
        aggregatedContext = AggregatedContext(
            biometric: latestBiometric,
            macOS: latestMacOSContext
        )
    }
}

#endif
