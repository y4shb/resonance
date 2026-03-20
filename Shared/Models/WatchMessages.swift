//
//  WatchMessages.swift
//  Resonance
//
//  Shared message types for WatchConnectivity between iPhone and Watch
//

import Foundation

// MARK: - Bookmark Trigger Source

enum BookmarkTriggerSource: String, Codable, Sendable {
    case watchDoubleTap = "watch_double_tap"
    case watchButton = "watch_button"
    case iphoneShake = "iphone_shake"
    case iphoneButton = "iphone_button"
}

// MARK: - Bookmark Trigger Packet (Watch -> Phone)

struct BookmarkTriggerPacket: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let triggerSource: String
    let heartRate: Double?
    let hrv: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        triggerSource: String,
        heartRate: Double? = nil,
        hrv: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.triggerSource = triggerSource
        self.heartRate = heartRate
        self.hrv = hrv
    }
}

// MARK: - Top-Level Message Envelope

enum WatchMessage: Codable, Sendable {
    // Watch -> Phone
    case biometricUpdate(BiometricPacket)
    case moodInput(MoodPacket)
    case playbackCommand(PlaybackCommand)
    case crownAdjustment(CrownAdjustment)
    case requestNowPlaying
    case bookmarkTrigger(BookmarkTriggerPacket)
    case overnightTemperature(OvernightTemperaturePacket)

    // Phone -> Watch
    case nowPlayingUpdate(NowPlayingPacket)
    case stateUpdate(StatePacket)
    case complicationUpdate(ComplicationData)
}

// MARK: - Watch -> Phone

struct PlaybackCommand: Codable, Sendable {
    enum Command: String, Codable, Sendable {
        case play, pause, skip, previous
    }
    let command: Command
}

struct BiometricPacket: Codable, Sendable {
    let heartRate: Double?
    let hrv: Double?
    let isStationary: Bool
    let isInWorkout: Bool
    let workoutType: String?
    let timestamp: Date
    /// Accelerometer magnitude (0.0 = stationary, 1.0+ = vigorous motion).
    /// Workstream 2.2: Used for motion-aware reward gating.
    let accelerometerMagnitude: Double?

    // MARK: - Emotion Detection Fields (all optional for backward compatibility)

    /// RMS of user acceleration magnitude over the sampling window (g).
    let movementMagnitude: Double?
    /// Standard deviation of acceleration magnitude.
    let movementVariability: Double?
    /// Shannon entropy of acceleration magnitude (binned).
    let movementEntropy: Double?
    /// RMS of gyroscope rotation rate (rad/s).
    let rotationMagnitude: Double?
    /// Acceleration peaks per second above threshold.
    let gestureFrequency: Double?
    /// Classified emotional state from Watch-side fuzzy classifier.
    let emotionalState: String?
    /// Confidence of the emotional state classification (0.0 - 1.0).
    let emotionConfidence: Double?
    /// Watch capability tier (full, motion, basic).
    let capabilityTier: String?

    // Backward-compatible decoding: new fields may be absent in older packets.
    private enum CodingKeys: String, CodingKey {
        case heartRate, hrv, isStationary, isInWorkout, workoutType, timestamp
        case accelerometerMagnitude
        case movementMagnitude, movementVariability, movementEntropy
        case rotationMagnitude, gestureFrequency
        case emotionalState, emotionConfidence, capabilityTier
    }

    init(
        heartRate: Double? = nil,
        hrv: Double? = nil,
        isStationary: Bool = true,
        isInWorkout: Bool = false,
        workoutType: String? = nil,
        timestamp: Date = Date(),
        accelerometerMagnitude: Double? = nil,
        movementMagnitude: Double? = nil,
        movementVariability: Double? = nil,
        movementEntropy: Double? = nil,
        rotationMagnitude: Double? = nil,
        gestureFrequency: Double? = nil,
        emotionalState: String? = nil,
        emotionConfidence: Double? = nil,
        capabilityTier: String? = nil
    ) {
        self.heartRate = heartRate
        self.hrv = hrv
        self.isStationary = isStationary
        self.isInWorkout = isInWorkout
        self.workoutType = workoutType
        self.timestamp = timestamp
        self.accelerometerMagnitude = accelerometerMagnitude
        self.movementMagnitude = movementMagnitude
        self.movementVariability = movementVariability
        self.movementEntropy = movementEntropy
        self.rotationMagnitude = rotationMagnitude
        self.gestureFrequency = gestureFrequency
        self.emotionalState = emotionalState
        self.emotionConfidence = emotionConfidence
        self.capabilityTier = capabilityTier
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        heartRate = try c.decodeIfPresent(Double.self, forKey: .heartRate)
        hrv = try c.decodeIfPresent(Double.self, forKey: .hrv)
        isStationary = try c.decodeIfPresent(Bool.self, forKey: .isStationary) ?? true
        isInWorkout = try c.decodeIfPresent(Bool.self, forKey: .isInWorkout) ?? false
        workoutType = try c.decodeIfPresent(String.self, forKey: .workoutType)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        accelerometerMagnitude = try c.decodeIfPresent(Double.self, forKey: .accelerometerMagnitude)
        movementMagnitude = try c.decodeIfPresent(Double.self, forKey: .movementMagnitude)
        movementVariability = try c.decodeIfPresent(Double.self, forKey: .movementVariability)
        movementEntropy = try c.decodeIfPresent(Double.self, forKey: .movementEntropy)
        rotationMagnitude = try c.decodeIfPresent(Double.self, forKey: .rotationMagnitude)
        gestureFrequency = try c.decodeIfPresent(Double.self, forKey: .gestureFrequency)
        emotionalState = try c.decodeIfPresent(String.self, forKey: .emotionalState)
        emotionConfidence = try c.decodeIfPresent(Double.self, forKey: .emotionConfidence)
        capabilityTier = try c.decodeIfPresent(String.self, forKey: .capabilityTier)
    }
}

// MARK: - Overnight Temperature Packet (Watch -> Phone)

struct OvernightTemperaturePacket: Codable, Sendable {
    /// Deviation from multi-night baseline (Celsius).
    let deviation: Double
    /// Multi-night baseline temperature (Celsius).
    let baseline: Double
    /// Latest overnight reading (Celsius).
    let latestReading: Double
    /// Trend direction: "rising", "falling", or "stable".
    let trend: String
    /// When this measurement was taken.
    let timestamp: Date
}

struct MoodPacket: Codable, Sendable {
    let moodLevel: Int        // 1-5 scale
    let energyLevel: Int      // 1-5 scale
    let timestamp: Date
}

struct CrownAdjustment: Codable, Sendable {
    let delta: Double         // -1.0 to 1.0
    let adjustmentType: String // "intensity", "energy"
}

// MARK: - Phone -> Watch

struct NowPlayingPacket: Codable, Sendable {
    let songTitle: String
    let artistName: String
    let artworkData: Data?    // Compressed thumbnail
    let isPlaying: Bool
    let progress: Double      // 0.0 - 1.0
    let duration: TimeInterval
    let explanation: String?  // Why this song was chosen
}

struct StatePacket: Codable, Sendable {
    let energyLevel: Double   // 0.0 - 1.0
    let calmLevel: Double     // 0.0 - 1.0
    let focusLevel: Double    // 0.0 - 1.0
    let heartRate: Double?
    let currentContext: String? // e.g. "workout", "focus", "relaxing"
    let timestamp: Date
}

struct ComplicationData: Codable, Sendable {
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
        case .biometricUpdate, .moodInput, .playbackCommand, .crownAdjustment, .requestNowPlaying, .bookmarkTrigger, .overnightTemperature:
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

enum WatchMessageError: Error, LocalizedError, Equatable, Sendable {
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
