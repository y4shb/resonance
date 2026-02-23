//
//  ActiveAppProvider.swift
//  ResonanceMac
//
//  Monitors the frontmost application on macOS.
//  Categorizes apps using the AppCategory enum from ContextSignal.swift.
//

#if os(macOS)

import Foundation
import AppKit
import Combine

/// Monitors the frontmost (active) application on macOS.
final class ActiveAppProvider: ObservableObject {

    @Published private(set) var activeAppBundleId: String?
    @Published private(set) var activeAppName: String?
    @Published private(set) var activeAppCategory: AppCategory = .unknown

    /// Tracks per-category time in the current hour (in seconds).
    private(set) var categoryTime: [AppCategory: TimeInterval] = [:]

    private var observer: Any?
    private var lastAppChangeTime: Date = Date()
    private var lastCategory: AppCategory = .unknown
    /// The hour component (0-23) when categoryTime was last updated.
    private var currentTrackingHour: Int = Calendar.current.component(.hour, from: Date())

    init() {
        logInfo("ActiveAppProvider initialized", category: .general)
    }

    deinit {
        stopMonitoring()
    }

    /// Starts observing frontmost application changes.
    func startMonitoring() {
        // Get initial state
        updateActiveApp()

        // Observe workspace app activation notifications
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }

    func stopMonitoring() {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    /// Returns minutes spent in a category in the current tracking period.
    func minutesInCategory(_ category: AppCategory) -> Double {
        resetCategoryTimeIfNeeded(now: Date())
        return (categoryTime[category] ?? 0) / 60.0
    }

    // MARK: - Private

    private func handleAppActivation(_ notification: Notification) {
        let now = Date()

        // Reset category time when the hour rolls over
        resetCategoryTimeIfNeeded(now: now)

        // Accumulate time for the previous app's category
        let elapsed = now.timeIntervalSince(lastAppChangeTime)
        categoryTime[lastCategory, default: 0] += elapsed
        lastAppChangeTime = now

        updateActiveApp()
    }

    /// Clears accumulated category time when the calendar hour changes.
    private func resetCategoryTimeIfNeeded(now: Date) {
        let hour = Calendar.current.component(.hour, from: now)
        if hour != currentTrackingHour {
            categoryTime.removeAll()
            currentTrackingHour = hour
            lastAppChangeTime = now
        }
    }

    private func updateActiveApp() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }

        let bundleId = frontmost.bundleIdentifier
        let appName = frontmost.localizedName

        activeAppBundleId = bundleId
        activeAppName = appName
        activeAppCategory = AppCategory.categorize(bundleId: bundleId)
        lastCategory = activeAppCategory
    }
}

#endif
