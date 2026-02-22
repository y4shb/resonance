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
import CloudKit

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

        // Subscribe to mood inputs from Watch
        watchManager.moodInputs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packet in
                self?.handleMoodInput(packet)
            }
            .store(in: &cancellables)

        // Start polling for macOS context via CloudKit
        startMacOSContextPolling()

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

            let eventUUID: UUID?
            if let oid = eventObjectID,
               let event = try? context.existingObject(with: oid) as? PlaybackEvent {
                eventUUID = event.id
            } else {
                eventUUID = nil
            }
            sample.setValue(eventUUID, forKey: "activePlaybackEventId")

            do {
                try context.save()
            } catch {
                logError("Failed to persist BiometricSample", error: error, category: .persistence)
            }
        }
    }

    // MARK: - Mood Input Handling

    /// Callback for StateEngine to receive mood inputs from Watch.
    var onMoodInput: ((MoodPacket) -> Void)?

    private func handleMoodInput(_ packet: MoodPacket) {
        logInfo(
            "Mood input received: energy=\(packet.energyLevel), mood=\(packet.moodLevel)",
            category: .general
        )
        onMoodInput?(packet)
    }

    // MARK: - macOS Context via CloudKit

    private var macOSPollTimer: Timer?

    private func startMacOSContextPolling() {
        // Poll CloudKit every 60 seconds for macOS context updates
        macOSPollTimer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            self?.fetchLatestMacOSContext()
        }

        // Initial fetch
        fetchLatestMacOSContext()
    }

    private func fetchLatestMacOSContext() {
        let container = CKContainer(identifier: "iCloud.com.y4sh.resonance")
        let database = container.privateCloudDatabase

        let query = CKQuery(
            recordType: "MacOSContext",
            predicate: NSPredicate(
                format: "timestamp > %@",
                Date().addingTimeInterval(-120) as NSDate  // Last 2 minutes
            )
        )
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (matchResults, _)):
                    guard let firstMatch = matchResults.first,
                          case .success(let record) = firstMatch.1 else {
                        return
                    }
                    self?.processMacOSContextRecord(record)
                case .failure(let error):
                    logDebug("CloudKit macOS context fetch: \(error.localizedDescription)", category: .network)
                }
            }
        }
    }

    private func processMacOSContextRecord(_ record: CKRecord) {
        let signal = MacOSContextSignal(
            focusModeActive: (record["focusModeActive"] as? NSNumber)?.boolValue ?? false,
            focusModeName: record["focusModeName"] as? String,
            activeAppName: record["activeAppName"] as? String,
            activeAppCategory: (record["activeAppCategory"] as? String).flatMap { AppCategory(rawValue: $0) },
            productivityMinutes: (record["productivityMinutes"] as? NSNumber)?.doubleValue ?? 0,
            entertainmentMinutes: (record["entertainmentMinutes"] as? NSNumber)?.doubleValue ?? 0,
            socialMinutes: (record["socialMinutes"] as? NSNumber)?.doubleValue ?? 0,
            hasOngoingMeeting: (record["hasOngoingMeeting"] as? NSNumber)?.boolValue ?? false,
            minutesUntilNextEvent: (record["minutesUntilNextEvent"] as? NSNumber)?.doubleValue,
            inferredWorkState: (record["inferredWorkState"] as? String).flatMap { WorkState(rawValue: $0) } ?? .idle
        )

        latestMacOSContext = signal
        rebuildAggregatedContext()

        logDebug(
            "macOS context received: work state=\(signal.inferredWorkState.rawValue), "
            + "focus=\(signal.focusModeActive)",
            category: .general
        )
    }

    // MARK: - Context Rebuild

    private func rebuildAggregatedContext() {
        aggregatedContext = AggregatedContext(
            biometric: latestBiometric,
            macOS: latestMacOSContext
        )
    }
}

#endif
