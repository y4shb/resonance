//
//  LiveActivityManager.swift
//  Resonance
//
//  Manages Live Activities for the Dynamic Island and Lock Screen.
//  Shows the current track with biometric state during active listening.
//  Also appears in the macOS menu bar on paired Macs (iOS 26+).
//

#if os(iOS)

import ActivityKit
import Foundation
import SwiftUI

// MARK: - Live Activity Attributes

/// Defines the static and dynamic content for the Resonance Live Activity.
struct ResonanceLiveActivityAttributes: ActivityAttributes {
    /// Static context (set when the activity starts, doesn't change).
    struct ContentState: Codable, Hashable {
        /// Current song title
        var songTitle: String

        /// Current artist name
        var artistName: String

        /// Whether audio is currently playing
        var isPlaying: Bool

        /// Playback progress (0.0 - 1.0)
        var progress: Double

        /// Duration of current track in seconds
        var duration: TimeInterval

        /// HRV zone name (Recovered / Normal / Stressed)
        var hrvZone: String

        /// HRV zone color as hex string
        var hrvZoneColorHex: String

        /// AI explanation snippet (short, max ~60 chars)
        var explanation: String?

        /// Current heart rate (optional)
        var heartRate: Int?
    }

    /// Session intent name (e.g., "Deep Work", "Workout")
    var sessionIntent: String
}

// MARK: - Live Activity Manager

/// Manages the lifecycle of Resonance's Live Activity.
@MainActor
final class LiveActivityManager {

    // MARK: - Properties

    private var currentActivity: Activity<ResonanceLiveActivityAttributes>?

    /// Whether a Live Activity is currently active.
    var isActive: Bool {
        currentActivity != nil
    }

    // MARK: - Start Activity

    /// Starts a new Live Activity for the current listening session.
    func startActivity(
        sessionIntent: String,
        songTitle: String,
        artistName: String,
        hrvZone: String = "Normal"
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logInfo("Live Activities are not enabled", category: .ui)
            return
        }

        let attributes = ResonanceLiveActivityAttributes(sessionIntent: sessionIntent)
        let contentState = ResonanceLiveActivityAttributes.ContentState(
            songTitle: songTitle,
            artistName: artistName,
            isPlaying: true,
            progress: 0,
            duration: 0,
            hrvZone: hrvZone,
            hrvZoneColorHex: hrvZoneColor(for: hrvZone),
            explanation: nil,
            heartRate: nil
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: nil),
                pushType: nil  // No push updates — we update locally
            )
            currentActivity = activity
            logInfo("Live Activity started: \(activity.id)", category: .ui)
        } catch {
            logError("Failed to start Live Activity", error: error, category: .ui)
        }
    }

    // MARK: - Update Activity

    /// Updates the Live Activity with new playback state.
    func updateActivity(
        songTitle: String,
        artistName: String,
        isPlaying: Bool,
        progress: Double,
        duration: TimeInterval,
        hrvZone: String,
        explanation: String?,
        heartRate: Int?
    ) {
        guard let activity = currentActivity else { return }

        let contentState = ResonanceLiveActivityAttributes.ContentState(
            songTitle: songTitle,
            artistName: artistName,
            isPlaying: isPlaying,
            progress: progress,
            duration: duration,
            hrvZone: hrvZone,
            hrvZoneColorHex: hrvZoneColor(for: hrvZone),
            explanation: explanation,
            heartRate: heartRate
        )

        Task {
            await activity.update(
                ActivityContent(state: contentState, staleDate: nil)
            )
        }
    }

    // MARK: - End Activity

    /// Ends the current Live Activity.
    func endActivity(
        songTitle: String = "Session Complete",
        artistName: String = ""
    ) {
        guard let activity = currentActivity else { return }

        let finalState = ResonanceLiveActivityAttributes.ContentState(
            songTitle: songTitle,
            artistName: artistName,
            isPlaying: false,
            progress: 1.0,
            duration: 0,
            hrvZone: "Recovered",
            hrvZoneColorHex: "#34C759",
            explanation: "Session ended",
            heartRate: nil
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now.addingTimeInterval(30))
            )
            currentActivity = nil
            logInfo("Live Activity ended", category: .ui)
        }
    }

    // MARK: - Helpers

    private func hrvZoneColor(for zone: String) -> String {
        switch zone.lowercased() {
        case "recovered": return "#34C759"  // Green
        case "normal": return "#FFCC00"     // Yellow
        case "stressed": return "#FF3B30"   // Red
        default: return "#FFCC00"
        }
    }
}

#endif
