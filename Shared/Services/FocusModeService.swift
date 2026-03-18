//
//  FocusModeService.swift
//  Resonance
//
//  Detects whether the user has an active iOS Focus mode (Do Not Disturb,
//  Work, Sleep, etc.) using INFocusStatusCenter. Exposes a published
//  isFocused property for integration into ContextCollector.
//  (Workstream 3.6)
//

#if os(iOS)

import Foundation
import Intents
import Combine

// MARK: - Focus Mode Service

/// Monitors iOS Focus mode status and publishes changes.
/// Uses `INFocusStatusCenter` to check whether a system Focus is active.
final class FocusModeService: ObservableObject {

    // MARK: - Published State

    /// Whether any Focus mode is currently active on the device.
    @Published private(set) var isFocused: Bool = false

    // MARK: - Private Properties

    private var pollTimer: Timer?
    private let pollIntervalSeconds: TimeInterval = 30

    // MARK: - Initialization

    init() {
        logInfo("FocusModeService initializing", category: .general)
        checkFocusStatus()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Focus Status Check

    /// Reads the current focus status from INFocusStatusCenter.
    /// Note: The app must include the Focus Status capability in its
    /// Info.plist (NSFocusStatusUsageDescription) for this to return
    /// meaningful results.
    func checkFocusStatus() {
        let center = INFocusStatusCenter.default
        let status = center.focusStatus

        let newValue = status.isFocused ?? false
        if newValue != isFocused {
            isFocused = newValue
            logInfo(
                "Focus mode status changed: \(newValue ? "active" : "inactive")",
                category: .general
            )
        }
    }

    // MARK: - Polling

    /// Polls focus status periodically since there is no notification API
    /// for focus status changes on iOS.
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: pollIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.checkFocusStatus()
        }
        pollTimer?.tolerance = 5.0
    }

    /// Stops the polling timer.
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

#endif
