//
//  WatchMessages.swift
//  Resonance
//
//  Shared message types for WatchConnectivity between iPhone and Watch
//

import Foundation

// MARK: - Top-Level Message Envelope

enum WatchMessage: Codable {
    // Watch -> Phone
    case biometricUpdate(BiometricPacket)
    case moodInput(MoodPacket)
    case playbackCommand(PlaybackCommand)
    case crownAdjustment(CrownAdjustment)
    case requestNowPlaying

    // Phone -> Watch
    case nowPlayingUpdate(NowPlayingPacket)
    case stateUpdate(StatePacket)
    case complicationUpdate(ComplicationData)
}

// MARK: - Watch -> Phone

struct PlaybackCommand: Codable {
    enum Command: String, Codable {
        case play, pause, skip, previous
    }
    let command: Command
}

struct BiometricPacket: Codable {
    let heartRate: Double?
    let hrv: Double?
    let isStationary: Bool
    let isInWorkout: Bool
    let workoutType: String?
    let timestamp: Date
}

struct MoodPacket: Codable {
    let moodLevel: Int        // 1-5 scale
    let energyLevel: Int      // 1-5 scale
    let timestamp: Date
}

struct CrownAdjustment: Codable {
    let delta: Double         // -1.0 to 1.0
    let adjustmentType: String // "intensity", "energy"
}

// MARK: - Phone -> Watch

struct NowPlayingPacket: Codable {
    let songTitle: String
    let artistName: String
    let artworkData: Data?    // Compressed thumbnail
    let isPlaying: Bool
    let progress: Double      // 0.0 - 1.0
    let duration: TimeInterval
    let explanation: String?  // Why this song was chosen
}

struct StatePacket: Codable {
    let energyLevel: Double   // 0.0 - 1.0
    let calmLevel: Double     // 0.0 - 1.0
    let focusLevel: Double    // 0.0 - 1.0
    let heartRate: Double?
    let currentContext: String? // e.g. "workout", "focus", "relaxing"
    let timestamp: Date
}

struct ComplicationData: Codable {
    let songTitle: String?
    let artistName: String?
    let stateEmoji: String    // e.g. "🎵", "🏃", "🧘"
    let heartRate: Double?
    let isPlaying: Bool
    let timestamp: Date
}

// MARK: - Encoding Helpers

extension WatchMessage {
    /// Key used in the WCSession dictionary for real-time messages (sendMessage).
    /// All message types share this key because sendMessage is per-delivery —
    /// there is no overwrite concern.
    private static let realtimeKey = "watchMessage"

    /// Key used in application context for now-playing data.
    /// Separate from stateUpdate/complicationUpdate so they don't overwrite each other.
    private static let contextKeyNowPlaying = "wm_nowPlaying"
    private static let contextKeyState = "wm_state"
    private static let contextKeyComplication = "wm_complication"

    /// The application-context key for this specific message type.
    /// Returns nil for watch→phone messages (they don't use context persistence).
    var applicationContextKey: String? {
        switch self {
        case .nowPlayingUpdate: return Self.contextKeyNowPlaying
        case .stateUpdate: return Self.contextKeyState
        case .complicationUpdate: return Self.contextKeyComplication
        case .biometricUpdate, .moodInput, .playbackCommand, .crownAdjustment, .requestNowPlaying:
            return nil
        }
    }

    /// Encode to dictionary for WCSession real-time transport (sendMessage).
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return [Self.realtimeKey: data]
    }

    /// Encode to dictionary for WCSession application context (persistent).
    /// Uses a message-type-specific key so different message types coexist.
    func toContextDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let key = applicationContextKey else {
            // Fallback for watch→phone messages that shouldn't use context
            return [Self.realtimeKey: data]
        }
        return [key: data]
    }

    /// Decode from WCSession dictionary (handles both realtime and context keys).
    static func fromDictionary(_ dict: [String: Any]) throws -> WatchMessage {
        // Try the realtime key first (used by sendMessage)
        if let data = dict[realtimeKey] as? Data {
            return try JSONDecoder().decode(WatchMessage.self, from: data)
        }
        throw WatchMessageError.decodingFailed
    }

    /// Decode all messages from an application context dictionary.
    /// Application context can contain multiple message-type keys simultaneously.
    static func allFromContextDictionary(_ dict: [String: Any]) -> [WatchMessage] {
        var messages: [WatchMessage] = []
        let contextKeys = [contextKeyNowPlaying, contextKeyState, contextKeyComplication]
        for key in contextKeys {
            if let data = dict[key] as? Data,
               let message = try? JSONDecoder().decode(WatchMessage.self, from: data) {
                messages.append(message)
            }
        }
        // Also check legacy single-key format for backwards compatibility
        if messages.isEmpty, let data = dict[realtimeKey] as? Data,
           let message = try? JSONDecoder().decode(WatchMessage.self, from: data) {
            messages.append(message)
        }
        return messages
    }
}

enum WatchMessageError: Error, LocalizedError, Equatable {
    case encodingFailed
    case decodingFailed
    case unknownMessageType

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode WatchMessage"
        case .decodingFailed: return "Failed to decode WatchMessage"
        case .unknownMessageType: return "Unknown WatchMessage type"
        }
    }
}
