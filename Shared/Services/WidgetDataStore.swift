//
//  WidgetDataStore.swift
//  Resonance
//
//  App Group UserDefaults bridge for iOS home screen and lock screen widgets.
//  Writes from the main app, reads from the Widget extension.
//  Mirrors the Watch ComplicationDataStore pattern.
//

import Foundation
import WidgetKit

/// Shared data store for iOS widget data.
/// Writes from the main iOS app, reads from the Widget extension.
/// Uses App Group UserDefaults for cross-process communication.
struct WidgetDataStore {
    private static let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard

    // MARK: - Keys

    private enum Keys {
        static let songTitle = "widget_songTitle"
        static let artistName = "widget_artistName"
        static let isPlaying = "widget_isPlaying"
        static let progress = "widget_progress"
        static let duration = "widget_duration"
        static let explanation = "widget_explanation"
        static let stateEmoji = "widget_stateEmoji"
        static let stateName = "widget_stateName"
        static let energy = "widget_energy"
        static let heartRate = "widget_heartRate"
        static let context = "widget_context"
        static let lastUpdated = "widget_lastUpdated"
        static let nowPlayingLastUpdated = "widget_nowPlayingLastUpdated"
        static let stateLastUpdated = "widget_stateLastUpdated"
    }

    // MARK: - Write (from main app)

    /// Updates the Now Playing widget data and triggers a timeline reload.
    static func updateNowPlaying(
        title: String,
        artist: String,
        isPlaying: Bool,
        progress: Double,
        duration: TimeInterval,
        explanation: String?
    ) {
        defaults.set(title, forKey: Keys.songTitle)
        defaults.set(artist, forKey: Keys.artistName)
        defaults.set(isPlaying, forKey: Keys.isPlaying)
        defaults.set(progress, forKey: Keys.progress)
        defaults.set(duration, forKey: Keys.duration)
        defaults.set(explanation, forKey: Keys.explanation)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.nowPlayingLastUpdated)
        WidgetCenter.shared.reloadTimelines(ofKind: "NowPlayingWidget")
    }

    /// Updates the State widget data and triggers a timeline reload.
    static func updateState(
        emoji: String,
        stateName: String,
        energy: Double,
        heartRate: Double?,
        context: String
    ) {
        defaults.set(emoji, forKey: Keys.stateEmoji)
        defaults.set(stateName, forKey: Keys.stateName)
        defaults.set(energy, forKey: Keys.energy)
        if let hr = heartRate {
            defaults.set(hr, forKey: Keys.heartRate)
        } else {
            defaults.removeObject(forKey: Keys.heartRate)
        }
        defaults.set(context, forKey: Keys.context)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.stateLastUpdated)
        WidgetCenter.shared.reloadTimelines(ofKind: "StateWidget")
    }

    // MARK: - Read (from Widget extension)

    /// Returns the current Now Playing snapshot from shared defaults.
    static var currentNowPlaying: WidgetNowPlayingSnapshot {
        WidgetNowPlayingSnapshot(
            songTitle: defaults.string(forKey: Keys.songTitle) ?? "No song playing",
            artistName: defaults.string(forKey: Keys.artistName) ?? "Open Resonance to start",
            isPlaying: defaults.bool(forKey: Keys.isPlaying),
            progress: defaults.double(forKey: Keys.progress),
            duration: defaults.double(forKey: Keys.duration),
            explanation: defaults.string(forKey: Keys.explanation),
            lastUpdated: Date(timeIntervalSince1970: defaults.double(forKey: Keys.nowPlayingLastUpdated))
        )
    }

    /// Returns the current State snapshot from shared defaults.
    static var currentState: WidgetStateSnapshot {
        WidgetStateSnapshot(
            stateEmoji: defaults.string(forKey: Keys.stateEmoji) ?? "\u{2753}",
            stateName: defaults.string(forKey: Keys.stateName) ?? "Unknown",
            energy: defaults.double(forKey: Keys.energy),
            heartRate: defaults.object(forKey: Keys.heartRate) as? Double,
            context: defaults.string(forKey: Keys.context) ?? "",
            lastUpdated: Date(timeIntervalSince1970: defaults.double(forKey: Keys.stateLastUpdated))
        )
    }
}

// MARK: - Snapshots

/// A point-in-time snapshot of Now Playing data read from shared defaults.
struct WidgetNowPlayingSnapshot: Sendable {
    let songTitle: String
    let artistName: String
    let isPlaying: Bool
    let progress: Double
    let duration: TimeInterval
    let explanation: String?
    let lastUpdated: Date

    /// Whether this snapshot is stale (older than 5 minutes).
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 300
    }
}

/// A point-in-time snapshot of State data read from shared defaults.
struct WidgetStateSnapshot: Sendable {
    let stateEmoji: String
    let stateName: String
    let energy: Double
    let heartRate: Double?
    let context: String
    let lastUpdated: Date

    /// Whether this snapshot is stale (older than 5 minutes).
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 300
    }
}
