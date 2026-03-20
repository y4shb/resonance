//
//  FocusModeProvider.swift
//  ResonanceMac
//
//  Detects the current Focus mode status on macOS.
//
//  Important: macOS has no public API equivalent to iOS's INFocusStatusCenter
//  for reading Focus mode state. The iOS counterpart (FocusModeService.swift)
//  uses the official INFocusStatusCenter API. On macOS, we use the
//  ~/Library/DoNotDisturb/DB/Assertions.json file which is the most reliable
//  approach available for macOS 12+. This is an undocumented path and may
//  change in future macOS releases. If the file is inaccessible (e.g. due to
//  sandboxing), Focus detection will gracefully degrade to "unknown".
//

#if os(macOS)

import Foundation
import Combine

/// Monitors macOS Focus mode (Do Not Disturb) state.
///
/// Uses the system's Focus assertion store (`~/Library/DoNotDisturb/DB/Assertions.json`)
/// and mode configuration (`~/Library/DoNotDisturb/DB/ModeConfigurations.json`) to
/// determine whether a Focus mode is active and, if so, which one.
///
/// Falls back to a legacy `UserDefaults` check for pre-Monterey compatibility.
final class FocusModeProvider: ObservableObject {

    @Published private(set) var isActive = false
    @Published private(set) var focusModeName: String?

    private var pollTimer: Timer?

    /// Path to the Focus assertions database.
    private let assertionsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/DoNotDisturb/DB/Assertions.json"
    }()

    /// Path to the Focus mode configurations database.
    private let configurationsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/DoNotDisturb/DB/ModeConfigurations.json"
    }()

    init() {
        logInfo("FocusModeProvider initialized", category: .general)
    }

    deinit {
        pollTimer?.invalidate()
    }

    /// Starts polling Focus mode status every 30 seconds.
    func startMonitoring() {
        pollTimer?.invalidate()
        checkFocusMode()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkFocusMode()
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Focus Detection

    private func checkFocusMode() {
        // Primary: Read the Focus assertions file (macOS 12+).
        // This file contains active Focus mode assertions with their mode identifiers.
        if let result = readFocusAssertions() {
            applyResult(active: result.active, name: result.name)
            return
        }

        // Fallback: Legacy UserDefaults check for older macOS versions.
        // The NSDoNotDisturbEnabled key was used pre-Monterey and may still
        // work on some system configurations.
        let dndDefaults = UserDefaults(suiteName: "com.apple.controlcenter")
        let dndEnabled = dndDefaults?.bool(forKey: "NSDoNotDisturbEnabled") ?? false

        applyResult(active: dndEnabled, name: dndEnabled ? "Do Not Disturb" : nil)
    }

    /// Reads the Focus assertions file to determine the active Focus mode.
    /// Returns nil if the file cannot be read (sandboxing, permissions, etc.).
    private func readFocusAssertions() -> (active: Bool, name: String?)? {
        guard FileManager.default.fileExists(atPath: assertionsPath) else {
            return nil
        }

        guard let assertionsData = FileManager.default.contents(atPath: assertionsPath) else {
            return nil
        }

        // Parse the assertions JSON to find active assertions.
        // Structure: { "data": [ { "storeAssertionRecords": [ { "assertionDetails": { "assertionDetailsModeIdentifier": "..." } } ] } ] }
        guard let json = try? JSONSerialization.jsonObject(with: assertionsData) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            return nil
        }

        // Look for any active assertion with a mode identifier
        for entry in dataArray {
            guard let records = entry["storeAssertionRecords"] as? [[String: Any]] else {
                continue
            }
            for record in records {
                guard let details = record["assertionDetails"] as? [String: Any],
                      let modeId = details["assertionDetailsModeIdentifier"] as? String else {
                    continue
                }
                // Found an active Focus assertion
                let resolvedName = resolveFocusModeName(modeId: modeId) ?? humanReadableId(modeId)
                return (active: true, name: resolvedName)
            }
        }

        return (active: false, name: nil)
    }

    /// Cross-references a mode identifier against the ModeConfigurations file
    /// to find the user-assigned Focus mode name.
    private func resolveFocusModeName(modeId: String) -> String? {
        guard let configData = FileManager.default.contents(atPath: configurationsPath),
              let json = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            return nil
        }

        for entry in dataArray {
            guard let configs = entry["modeConfigurations"] as? [String: Any],
                  let modeConfig = configs[modeId] as? [String: Any],
                  let configuration = modeConfig["configuration"] as? [String: Any],
                  let name = configuration["name"] as? String else {
                continue
            }
            return name
        }

        return nil
    }

    /// Converts a Focus mode identifier like "com.apple.focus.work" to a
    /// human-readable fallback name like "Work".
    private func humanReadableId(_ modeId: String) -> String {
        // Extract the last path component and capitalize it
        let lastComponent = modeId.components(separatedBy: ".").last ?? modeId
        let cleaned = lastComponent.replacingOccurrences(of: "-", with: " ")
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    /// Applies the detection result and logs changes.
    private func applyResult(active: Bool, name: String?) {
        let wasActive = isActive
        isActive = active
        focusModeName = name

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
