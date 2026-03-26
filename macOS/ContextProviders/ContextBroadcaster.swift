//
//  ContextBroadcaster.swift
//  ResonanceMac
//
//  Aggregates signals from FocusModeProvider, ActiveAppProvider, and CalendarProvider
//  into a MacOSContextSignal. Broadcasts to iPhone via CloudKit.
//  Also polls CloudKit for iPhone now playing state.
//

#if os(macOS)

import Foundation
import Combine
import CloudKit

/// Aggregates macOS context signals and syncs to iPhone via CloudKit.
/// Also polls for iPhone now playing state from CloudKit.
final class ContextBroadcaster: ObservableObject {

    // MARK: - Dependencies

    let focusModeProvider: FocusModeProvider
    let activeAppProvider: ActiveAppProvider
    let calendarProvider: CalendarProvider

    // MARK: - State

    @Published private(set) var latestSignal: MacOSContextSignal?
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var isSyncing = false

    /// Latest now playing info fetched from CloudKit (published by iPhone).
    @Published private(set) var latestNowPlaying: NowPlayingPacket?

    private var broadcastTimer: Timer?
    private var nowPlayingPollTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var lastFailedSignal: MacOSContextSignal?
    private var isRunning = false
    private var activeSaveCount = 0
    private var activeRetryTask: Task<Void, Never>?

    // CloudKit -- lazy to avoid crash if entitlements are misconfigured
    private lazy var container: CKContainer? = {
        let id = AppConstants.cloudKitContainerIdentifier
        guard !id.isEmpty else {
            logWarning("ContextBroadcaster: CloudKit container identifier is empty", category: .macOSContext)
            return nil
        }
        return CKContainer(identifier: id)
    }()
    private let recordType = "MacOSContext"
    private let nowPlayingRecordType = "iPhoneNowPlaying"

    // MARK: - Initialization

    init(
        focusModeProvider: FocusModeProvider = FocusModeProvider(),
        activeAppProvider: ActiveAppProvider = ActiveAppProvider(),
        calendarProvider: CalendarProvider = CalendarProvider()
    ) {
        self.focusModeProvider = focusModeProvider
        self.activeAppProvider = activeAppProvider
        self.calendarProvider = calendarProvider
        logInfo("ContextBroadcaster initialized", category: .general)
    }

    deinit {
        broadcastTimer?.invalidate()
        activeRetryTask?.cancel()
        nowPlayingPollTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Starts all providers, periodic context broadcasting, and now playing polling.
    func startBroadcasting() {
        guard !isRunning else {
            logDebug("ContextBroadcaster already running", category: .general)
            return
        }
        isRunning = true

        focusModeProvider.startMonitoring()
        activeAppProvider.startMonitoring()
        calendarProvider.startMonitoring()

        // Broadcast context every 60 seconds
        broadcastTimer?.invalidate()
        broadcastTimer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            self?.broadcastContext()
        }

        // Initial broadcast after a short delay for providers to populate
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.broadcastContext()
        }

        // Start polling for iPhone now playing state
        startNowPlayingPolling()

        logInfo("ContextBroadcaster started broadcasting", category: .general)
    }

    func stopBroadcasting() {
        isRunning = false
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        activeRetryTask?.cancel()
        activeRetryTask = nil
        nowPlayingPollTask?.cancel()
        nowPlayingPollTask = nil
        focusModeProvider.stopMonitoring()
        activeAppProvider.stopMonitoring()
        calendarProvider.stopMonitoring()
    }

    // MARK: - Signal Aggregation

    /// Builds a MacOSContextSignal from all providers.
    func buildSignal() -> MacOSContextSignal {
        let workState = inferWorkState()

        return MacOSContextSignal(
            focusModeActive: focusModeProvider.isActive,
            focusModeName: focusModeProvider.focusModeName,
            activeAppBundleId: activeAppProvider.activeAppBundleId,
            activeAppName: activeAppProvider.activeAppName,
            activeAppCategory: activeAppProvider.activeAppCategory,
            productivityMinutes: activeAppProvider.minutesInCategory(.productivity)
                + activeAppProvider.minutesInCategory(.development),
            entertainmentMinutes: activeAppProvider.minutesInCategory(.entertainment),
            socialMinutes: activeAppProvider.minutesInCategory(.social)
                + activeAppProvider.minutesInCategory(.communication),
            hasOngoingMeeting: calendarProvider.hasOngoingMeeting,
            minutesUntilNextEvent: calendarProvider.minutesUntilNextEvent,
            nextEventType: calendarProvider.nextEventType,
            inferredWorkState: workState
        )
    }

    // MARK: - Work State Inference

    private func inferWorkState() -> WorkState {
        // Meeting overrides everything
        if calendarProvider.hasOngoingMeeting {
            return .meetings
        }

        // Focus mode + productivity app = deep work
        if focusModeProvider.isActive {
            let appCat = activeAppProvider.activeAppCategory
            if appCat == .development || appCat == .productivity || appCat == .creative {
                return .deepWork
            }
        }

        // Productivity/development app = casual work
        let appCat = activeAppProvider.activeAppCategory
        switch appCat {
        case .development, .productivity, .creative:
            return .casual
        case .entertainment:
            return .entertainment
        default:
            break
        }

        // Check time spent: if > 20 min productivity in last hour, likely working
        let productivityMinutes = activeAppProvider.minutesInCategory(.productivity)
            + activeAppProvider.minutesInCategory(.development)
        if productivityMinutes > 20 {
            return .casual
        }

        return .idle
    }

    // MARK: - CloudKit Broadcast

    private func broadcastContext() {
        // Retry last-failed signal first, if any
        if let failedSignal = lastFailedSignal {
            logInfo("Retrying previously failed context broadcast before current", category: .macOSContext)
            lastFailedSignal = nil
            saveSignalToCloudKit(failedSignal, attempt: 1, maxAttempts: 3)
        }

        let signal = buildSignal()
        latestSignal = signal

        saveSignalToCloudKit(signal, attempt: 1, maxAttempts: 3)
    }

    private func saveSignalToCloudKit(_ signal: MacOSContextSignal, attempt: Int, maxAttempts: Int) {
        activeSaveCount += 1
        isSyncing = true

        let record = CKRecord(recordType: recordType)
        record["timestamp"] = signal.timestamp as NSDate
        record["focusModeActive"] = signal.focusModeActive as NSNumber
        record["focusModeName"] = signal.focusModeName as NSString?
        record["activeAppName"] = signal.activeAppName as NSString?
        record["activeAppBundleId"] = signal.activeAppBundleId as NSString?
        record["activeAppCategory"] = signal.activeAppCategory?.rawValue as NSString?
        record["productivityMinutes"] = signal.productivityMinutes as NSNumber
        record["entertainmentMinutes"] = signal.entertainmentMinutes as NSNumber
        record["socialMinutes"] = signal.socialMinutes as NSNumber
        record["hasOngoingMeeting"] = signal.hasOngoingMeeting as NSNumber
        record["minutesUntilNextEvent"] = signal.minutesUntilNextEvent.map { $0 as NSNumber }
        record["nextEventType"] = signal.nextEventType?.rawValue as NSString?
        record["inferredWorkState"] = signal.inferredWorkState.rawValue as NSString

        guard let container = container else {
            logWarning("ContextBroadcaster: CloudKit container not available, skipping save", category: .macOSContext)
            return
        }
        let database = container.privateCloudDatabase
        database.save(record) { [weak self] _, error in
            DispatchQueue.main.async {
                if let self = self {
                    self.activeSaveCount -= 1
                    self.isSyncing = self.activeSaveCount > 0
                }
                if let error = error {
                    if attempt < maxAttempts {
                        logInfo("Retrying failed context broadcast (attempt \(attempt + 1)/\(maxAttempts))", category: .macOSContext)
                        let delaySeconds = pow(2.0, Double(attempt - 1)) // 1s, 2s, 4s
                        self?.activeRetryTask?.cancel()
                        self?.activeRetryTask = Task { [weak self] in
                            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                self?.saveSignalToCloudKit(signal, attempt: attempt + 1, maxAttempts: maxAttempts)
                            }
                        }
                    } else {
                        logError("ContextBroadcaster: CloudKit save failed after \(maxAttempts) attempts", error: error, category: .macOSContext)
                        self?.lastFailedSignal = signal
                    }
                } else {
                    self?.lastSyncDate = Date()
                    logDebug(
                        "ContextBroadcaster: synced context (work state: \(signal.inferredWorkState.rawValue))",
                        category: .network
                    )
                }
            }
        }
    }

    // MARK: - Now Playing CloudKit Polling

    /// Polls CloudKit for iPhone now playing state every 15 seconds.
    private func startNowPlayingPolling() {
        nowPlayingPollTask?.cancel()

        // Initial fetch
        fetchNowPlaying()

        nowPlayingPollTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                } catch {
                    break // Task was cancelled
                }
                await MainActor.run {
                    self?.fetchNowPlaying()
                }
            }
        }
    }

    /// Fetches the latest now playing record from CloudKit (published by the iPhone app).
    private func fetchNowPlaying() {
        guard let container = container else { return }

        let database = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: "currentNowPlaying")

        database.fetch(withRecordID: recordID) { [weak self] record, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    // CKError.unknownItem means no record exists (nothing playing)
                    let ckError = error as? CKError
                    if ckError?.code == .unknownItem {
                        self.latestNowPlaying = nil
                    } else {
                        logDebug(
                            "ContextBroadcaster: now playing fetch failed: \(error.localizedDescription)",
                            category: .network
                        )
                    }
                    return
                }

                guard let record = record else {
                    self.latestNowPlaying = nil
                    return
                }

                self.processNowPlayingRecord(record)
            }
        }
    }

    /// Converts a CloudKit record into a NowPlayingPacket.
    private func processNowPlayingRecord(_ record: CKRecord) {
        let songTitle = (record["songTitle"] as? String) ?? "Unknown"
        let artistName = (record["artistName"] as? String) ?? "Unknown"
        let isPlaying = (record["isPlaying"] as? NSNumber)?.boolValue ?? false
        let progress = (record["progress"] as? NSNumber)?.doubleValue ?? 0
        let duration = (record["duration"] as? NSNumber)?.doubleValue ?? 0
        let explanation = record["explanation"] as? String

        // Check staleness: if the record is older than 5 minutes, treat as stale
        if let timestamp = record["timestamp"] as? Date,
           Date().timeIntervalSince(timestamp) > 300 {
            latestNowPlaying = nil
            logDebug("ContextBroadcaster: now playing record is stale, clearing", category: .network)
            return
        }

        // Load artwork from CKAsset if available
        var artworkData: Data?
        if let asset = record["artwork"] as? CKAsset,
           let fileURL = asset.fileURL {
            artworkData = try? Data(contentsOf: fileURL)
        }

        let packet = NowPlayingPacket(
            songTitle: songTitle,
            artistName: artistName,
            artworkData: artworkData,
            isPlaying: isPlaying,
            progress: progress,
            duration: duration,
            explanation: explanation
        )

        latestNowPlaying = packet
        lastSyncDate = Date()

        logDebug(
            "ContextBroadcaster: now playing received: \(songTitle) by \(artistName)",
            category: .network
        )
    }
}

#endif
