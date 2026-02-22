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
        let signal = buildSignal()
        latestSignal = signal

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
                self?.isSyncing = false
                if let error = error {
                    logError("ContextBroadcaster: CloudKit save failed", error: error, category: .network)
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
