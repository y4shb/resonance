//
//  FocusModeProvider.swift
//  ResonanceMac
//
//  Detects the current Focus mode status on macOS.
//  Uses DNDManager-equivalent observation to determine if Do Not Disturb
//  or a custom Focus mode is active.
//

#if os(macOS)

import Foundation
import Combine

/// Monitors macOS Focus mode (Do Not Disturb) state.
final class FocusModeProvider: ObservableObject {

    @Published private(set) var isActive: Bool = false
    @Published private(set) var focusModeName: String?

    private var pollTimer: Timer?

    init() {
        logInfo("FocusModeProvider initialized", category: .general)
    }

    deinit {
        pollTimer?.invalidate()
    }

    /// Starts polling Focus mode status every 30 seconds.
    func startMonitoring() {
        checkFocusMode()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkFocusMode()
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkFocusMode() {
        // macOS DND/Focus detection via NSDoNotDisturbEnabled defaults key
        // This is the most reliable non-private-API approach

        // Check DND status via defaults
        let dndDefaults = UserDefaults(suiteName: "com.apple.controlcenter")
        let dndEnabled = dndDefaults?.bool(forKey: "NSDoNotDisturbEnabled") ?? false

        // Alternative: check Focus status via assertion store
        let assertionDefaults = UserDefaults(suiteName: "com.apple.focus")
        let focusName = assertionDefaults?.string(forKey: "activeFocusMode")

        let wasActive = isActive
        isActive = dndEnabled || focusName != nil
        focusModeName = focusName ?? (dndEnabled ? "Do Not Disturb" : nil)

        if isActive != wasActive {
            logDebug(
                "Focus mode changed: \(isActive ? "active" : "inactive")"
                + (focusModeName.map { " (\($0))" } ?? ""),
                category: .general
            )
        }
    }
}

#endif
