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
    /// Encode to dictionary for WCSession transport
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return ["watchMessage": data]
    }

    /// Decode from WCSession dictionary
    static func fromDictionary(_ dict: [String: Any]) throws -> WatchMessage {
        guard let data = dict["watchMessage"] as? Data else {
            throw WatchMessageError.decodingFailed
        }
        return try JSONDecoder().decode(WatchMessage.self, from: data)
    }
}

enum WatchMessageError: Error, LocalizedError {
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
