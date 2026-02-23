//
//  ContextBroadcaster.swift
//  ResonanceMac
//
//  Aggregates signals from FocusModeProvider, ActiveAppProvider, and CalendarProvider
//  into a MacOSContextSignal. Broadcasts to iPhone via CloudKit.
//

#if os(macOS)

import Foundation
import Combine
import CloudKit

/// Aggregates macOS context signals and syncs to iPhone via CloudKit.
final class ContextBroadcaster: ObservableObject {

    // MARK: - Dependencies

    let focusModeProvider: FocusModeProvider
    let activeAppProvider: ActiveAppProvider
    let calendarProvider: CalendarProvider

    // MARK: - State

    @Published private(set) var latestSignal: MacOSContextSignal?
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var isSyncing = false

    private var broadcastTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastFailedSignal: MacOSContextSignal?
    private var isRunning = false
    private var activeSaveCount = 0

    // CloudKit
    private lazy var container = CKContainer(identifier: "iCloud.com.y4sh.resonance")
    private let recordType = "MacOSContext"

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
    }

    // MARK: - Lifecycle

    /// Starts all providers and periodic broadcasting.
    func startBroadcasting() {
        guard !isRunning else {
            logDebug("ContextBroadcaster already running", category: .general)
            return
        }
        isRunning = true

        focusModeProvider.startMonitoring()
        activeAppProvider.startMonitoring()
        calendarProvider.startMonitoring()

        // Broadcast every 60 seconds
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

        logInfo("ContextBroadcaster started broadcasting", category: .general)
    }

    func stopBroadcasting() {
        isRunning = false
        broadcastTimer?.invalidate()
        broadcastTimer = nil
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
        record["activeAppCategory"] = signal.activeAppCategory?.rawValue as NSString?
        record["productivityMinutes"] = signal.productivityMinutes as NSNumber
        record["entertainmentMinutes"] = signal.entertainmentMinutes as NSNumber
        record["socialMinutes"] = signal.socialMinutes as NSNumber
        record["hasOngoingMeeting"] = signal.hasOngoingMeeting as NSNumber
        record["minutesUntilNextEvent"] = signal.minutesUntilNextEvent.map { $0 as NSNumber }
        record["inferredWorkState"] = signal.inferredWorkState.rawValue as NSString

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
                        Task {
                            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
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
}

#endif
