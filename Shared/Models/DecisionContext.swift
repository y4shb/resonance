//
//  DecisionContext.swift
//  Resonance
//
//  All context needed to make a song selection decision
//

import Foundation

/// All context needed to make a song selection decision
public struct DecisionContext: Sendable {
    /// Current state of the user
    public let stateVector: StateVector

    /// Active playlist ID to select from
    public let activePlaylistId: UUID

    /// Active playlist name (for display)
    public let activePlaylistName: String

    /// Song IDs in the playlist (for candidate selection)
    public let candidateSongIds: [UUID]

    /// Recently played songs (for recency filtering)
    /// Key: songId, Value: lastPlayedAt
    public let recentlyPlayed: [UUID: Date]

    /// Current time for time-of-day rules
    public let currentTime: Date

    /// Session history - song IDs played in current session (for transition logic)
    public let currentSessionSongIds: [UUID]

    /// User preferences
    public let preferences: UserPreferences

    /// Whether this is the first song of a session
    public let isSessionStart: Bool

    // MARK: - Initialization

    public init(
        stateVector: StateVector,
        activePlaylistId: UUID,
        activePlaylistName: String,
        candidateSongIds: [UUID],
        recentlyPlayed: [UUID: Date] = [:],
        currentTime: Date = Date(),
        currentSessionSongIds: [UUID] = [],
        preferences: UserPreferences = UserPreferences(),
        isSessionStart: Bool = false
    ) {
        self.stateVector = stateVector
        self.activePlaylistId = activePlaylistId
        self.activePlaylistName = activePlaylistName
        self.candidateSongIds = candidateSongIds
        self.recentlyPlayed = recentlyPlayed
        self.currentTime = currentTime
        self.currentSessionSongIds = currentSessionSongIds
        self.preferences = preferences
        self.isSessionStart = isSessionStart
    }
}

// MARK: - Convenience Methods

extension DecisionContext {
    /// Returns the current hour (0-23)
    public var currentHour: Int {
        Calendar.current.component(.hour, from: currentTime)
    }

    /// Returns true if it's nighttime (after 9 PM or before 6 AM)
    public var isNighttime: Bool {
        currentHour >= 21 || currentHour < 6
    }

    /// Returns true if it's morning (6 AM - 10 AM)
    public var isMorning: Bool {
        currentHour >= 6 && currentHour < 10
    }

    /// Returns the time slot for the current time
    public var timeSlot: TimeSlot {
        switch currentHour {
        case 5..<9: return .earlyMorning
        case 9..<12: return .morning
        case 12..<14: return .midday
        case 14..<17: return .afternoon
        case 17..<21: return .evening
        case 21..<24, 0..<5: return .night
        default: return .unknown
        }
    }

    /// Returns how many songs are available for selection
    public var availableSongCount: Int {
        candidateSongIds.count
    }

    /// Returns the number of songs played in current session
    public var sessionSongCount: Int {
        currentSessionSongIds.count
    }

    /// Checks if a song was played recently (within avoidRecentMinutes)
    public func wasPlayedRecently(_ songId: UUID) -> Bool {
        guard let lastPlayed = recentlyPlayed[songId] else {
            return false
        }
        let minutesSince = currentTime.timeIntervalSince(lastPlayed) / 60
        return minutesSince < Double(preferences.avoidRecentMinutes)
    }

    /// Returns minutes since a song was last played (nil if never)
    public func minutesSinceLastPlayed(_ songId: UUID) -> Double? {
        guard let lastPlayed = recentlyPlayed[songId] else {
            return nil
        }
        return currentTime.timeIntervalSince(lastPlayed) / 60
    }
}

// MARK: - Time Slot

public enum TimeSlot: String, Codable, CaseIterable, Sendable {
    case earlyMorning = "early_morning"  // 5-9 AM
    case morning = "morning"              // 9-12 PM
    case midday = "midday"                // 12-2 PM
    case afternoon = "afternoon"          // 2-5 PM
    case evening = "evening"              // 5-9 PM
    case night = "night"                  // 9 PM - 5 AM
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .earlyMorning: return "Early Morning"
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        case .unknown: return "Unknown"
        }
    }

    /// Suggested maximum BPM for this time slot
    public var suggestedMaxBPM: Double {
        switch self {
        case .earlyMorning: return 100
        case .morning: return 130
        case .midday: return 140
        case .afternoon: return 140
        case .evening: return 120
        case .night: return 90
        case .unknown: return 120
        }
    }
}

// MARK: - Factory Methods

extension DecisionContext {
    /// Creates a placeholder context for testing
    public static func placeholder() -> DecisionContext {
        DecisionContext(
            stateVector: .empty,
            activePlaylistId: UUID(),
            activePlaylistName: "Test Playlist",
            candidateSongIds: [],
            isSessionStart: true
        )
    }
}
