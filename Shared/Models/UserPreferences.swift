//
//  UserPreferences.swift
//  Resonance
//
//  User-configurable preferences for the AI DJ system
//

import Foundation

/// User-configurable preferences
public struct UserPreferences: Codable, Sendable {

    // MARK: - Ranking Weights (should sum to approximately 1.0)

    /// Weight for BPM matching in song scoring
    public var bpmWeight: Double

    /// Weight for energy level matching
    public var energyWeight: Double

    /// Weight for song familiarity
    public var familiarityWeight: Double

    /// Weight for historical effectiveness
    public var historicalWeight: Double

    /// Weight for context alignment
    public var contextWeight: Double

    // MARK: - Behavioral Preferences

    /// Don't repeat songs within this many minutes
    public var avoidRecentMinutes: Int

    /// Maximum songs from the same artist in a row
    public var maxSameArtistInRow: Int

    /// Prefer familiar songs when user is stressed
    public var preferFamiliarInStress: Bool

    /// Enable smooth transitions between songs
    public var enableSmoothTransitions: Bool

    // MARK: - Time of Day Rules

    /// Maximum BPM for morning hours
    public var morningMaxBPM: Double

    /// Maximum BPM for night hours
    public var nightMaxBPM: Double

    /// Hour when night mode starts (24-hour format)
    public var nightStartHour: Int

    /// Hour when morning mode ends (24-hour format)
    public var morningEndHour: Int

    // MARK: - Learning Sensitivity

    /// How much to penalize skipped songs (0.0 - 1.0)
    public var skipPenaltyWeight: Double

    /// How much to credit HRV improvement (0.0 - 1.0)
    public var hrvResponseWeight: Double

    /// Learning rate for effect score updates (0.0 - 1.0)
    public var learningRate: Double

    // MARK: - Privacy

    /// Whether to share anonymous analytics
    public var shareAnalytics: Bool

    /// Whether to backup data to iCloud
    public var backupToiCloud: Bool

    // MARK: - Crossfade

    /// Whether crossfade transitions are enabled between songs
    public var crossfadeEnabled: Bool

    /// Crossfade duration in seconds (1-10)
    public var crossfadeDuration: Double

    /// Whether biometric-adaptive crossfade is enabled (adjusts crossfade duration
    /// based on heart rate and HRV in real time)
    public var biometricCrossfadeEnabled: Bool

    /// Whether the AI DJ can pick songs from playlists other than the active one
    /// when they fit the current mood better
    public var allowCrossPlaylistRecommendations: Bool

    // MARK: - Biometric Signal Toggles

    /// Whether heart rate data influences song selection
    public var heartRateEnabled: Bool

    /// Whether HRV data influences song selection
    public var hrvEnabled: Bool

    /// Whether motion/accelerometer data influences song selection
    public var motionEnabled: Bool

    /// Whether sleep data influences song selection
    public var sleepEnabled: Bool

    /// Whether wrist temperature data influences song selection
    public var temperatureEnabled: Bool

    /// How aggressively biometrics influence song selection (0.0 = ignore, 1.0 = maximum)
    public var biometricSensitivity: Double

    // MARK: - AI Preferences

    /// Exploration bias: 0.0 = only familiar songs, 1.0 = maximum exploration
    public var explorationBias: Double

    /// Body vs Mind weight: 0.0 = pure mood input, 1.0 = pure biometric
    public var bodyVsMindWeight: Double

    /// DJ autonomy: how independently the AI acts (0.0 = manual, 1.0 = fully autonomous)
    public var djAutonomy: Double

    /// AI explanation verbosity: 0 = silent, 1 = minimal, 2 = detailed
    public var aiVerbosity: Int

    // MARK: - Session Defaults

    /// Default session duration in minutes
    public var defaultSessionDuration: Int

    /// Default session intent (raw value of SessionIntent)
    public var defaultSessionIntent: String

    // MARK: - Initialization

    public init(
        bpmWeight: Double = 0.15,
        energyWeight: Double = 0.20,
        familiarityWeight: Double = 0.15,
        historicalWeight: Double = 0.25,
        contextWeight: Double = 0.25,
        avoidRecentMinutes: Int = 60,
        maxSameArtistInRow: Int = 2,
        preferFamiliarInStress: Bool = true,
        enableSmoothTransitions: Bool = true,
        morningMaxBPM: Double = 120,
        nightMaxBPM: Double = 100,
        nightStartHour: Int = 21,
        morningEndHour: Int = 9,
        skipPenaltyWeight: Double = 0.5,
        hrvResponseWeight: Double = 0.3,
        learningRate: Double = 0.2,
        shareAnalytics: Bool = false,
        backupToiCloud: Bool = true,
        crossfadeEnabled: Bool = true,
        crossfadeDuration: Double = 4.0,
        biometricCrossfadeEnabled: Bool = true,
        allowCrossPlaylistRecommendations: Bool = false,
        heartRateEnabled: Bool = true,
        hrvEnabled: Bool = true,
        motionEnabled: Bool = true,
        sleepEnabled: Bool = true,
        temperatureEnabled: Bool = true,
        biometricSensitivity: Double = 0.5,
        explorationBias: Double = 0.3,
        bodyVsMindWeight: Double = 0.5,
        djAutonomy: Double = 0.7,
        aiVerbosity: Int = 1,
        defaultSessionDuration: Int = 60,
        defaultSessionIntent: String = "Auto-Detect"
    ) {
        self.bpmWeight = bpmWeight
        self.energyWeight = energyWeight
        self.familiarityWeight = familiarityWeight
        self.historicalWeight = historicalWeight
        self.contextWeight = contextWeight
        self.avoidRecentMinutes = avoidRecentMinutes
        self.maxSameArtistInRow = maxSameArtistInRow
        self.preferFamiliarInStress = preferFamiliarInStress
        self.enableSmoothTransitions = enableSmoothTransitions
        self.morningMaxBPM = morningMaxBPM
        self.nightMaxBPM = nightMaxBPM
        self.nightStartHour = nightStartHour
        self.morningEndHour = morningEndHour
        self.skipPenaltyWeight = skipPenaltyWeight
        self.hrvResponseWeight = hrvResponseWeight
        self.learningRate = learningRate
        self.shareAnalytics = shareAnalytics
        self.backupToiCloud = backupToiCloud
        self.crossfadeEnabled = crossfadeEnabled
        self.crossfadeDuration = crossfadeDuration
        self.biometricCrossfadeEnabled = biometricCrossfadeEnabled
        self.allowCrossPlaylistRecommendations = allowCrossPlaylistRecommendations
        self.heartRateEnabled = heartRateEnabled
        self.hrvEnabled = hrvEnabled
        self.motionEnabled = motionEnabled
        self.sleepEnabled = sleepEnabled
        self.temperatureEnabled = temperatureEnabled
        self.biometricSensitivity = biometricSensitivity
        self.explorationBias = explorationBias
        self.bodyVsMindWeight = bodyVsMindWeight
        self.djAutonomy = djAutonomy
        self.aiVerbosity = aiVerbosity
        self.defaultSessionDuration = defaultSessionDuration
        self.defaultSessionIntent = defaultSessionIntent
    }

    // MARK: - Codable (Backward Compatible)

    private enum CodingKeys: String, CodingKey {
        case bpmWeight, energyWeight, familiarityWeight, historicalWeight, contextWeight
        case avoidRecentMinutes, maxSameArtistInRow, preferFamiliarInStress, enableSmoothTransitions
        case morningMaxBPM, nightMaxBPM, nightStartHour, morningEndHour
        case skipPenaltyWeight, hrvResponseWeight, learningRate
        case shareAnalytics, backupToiCloud
        case crossfadeEnabled, crossfadeDuration, biometricCrossfadeEnabled
        case allowCrossPlaylistRecommendations
        case heartRateEnabled, hrvEnabled, motionEnabled, sleepEnabled, temperatureEnabled
        case biometricSensitivity
        case explorationBias, bodyVsMindWeight, djAutonomy, aiVerbosity
        case defaultSessionDuration, defaultSessionIntent
    }

    /// Custom decoder that handles missing fields from older saved JSON.
    /// New fields use defaults when absent, preserving existing user preferences.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        bpmWeight = try c.decodeIfPresent(Double.self, forKey: .bpmWeight) ?? 0.15
        energyWeight = try c.decodeIfPresent(Double.self, forKey: .energyWeight) ?? 0.20
        familiarityWeight = try c.decodeIfPresent(Double.self, forKey: .familiarityWeight) ?? 0.15
        historicalWeight = try c.decodeIfPresent(Double.self, forKey: .historicalWeight) ?? 0.25
        contextWeight = try c.decodeIfPresent(Double.self, forKey: .contextWeight) ?? 0.25
        avoidRecentMinutes = try c.decodeIfPresent(Int.self, forKey: .avoidRecentMinutes) ?? 60
        maxSameArtistInRow = try c.decodeIfPresent(Int.self, forKey: .maxSameArtistInRow) ?? 2
        preferFamiliarInStress = try c.decodeIfPresent(Bool.self, forKey: .preferFamiliarInStress) ?? true
        enableSmoothTransitions = try c.decodeIfPresent(Bool.self, forKey: .enableSmoothTransitions) ?? true
        morningMaxBPM = try c.decodeIfPresent(Double.self, forKey: .morningMaxBPM) ?? 120
        nightMaxBPM = try c.decodeIfPresent(Double.self, forKey: .nightMaxBPM) ?? 100
        nightStartHour = try c.decodeIfPresent(Int.self, forKey: .nightStartHour) ?? 21
        morningEndHour = try c.decodeIfPresent(Int.self, forKey: .morningEndHour) ?? 9
        skipPenaltyWeight = try c.decodeIfPresent(Double.self, forKey: .skipPenaltyWeight) ?? 0.5
        hrvResponseWeight = try c.decodeIfPresent(Double.self, forKey: .hrvResponseWeight) ?? 0.3
        learningRate = try c.decodeIfPresent(Double.self, forKey: .learningRate) ?? 0.2
        shareAnalytics = try c.decodeIfPresent(Bool.self, forKey: .shareAnalytics) ?? false
        backupToiCloud = try c.decodeIfPresent(Bool.self, forKey: .backupToiCloud) ?? true
        // New fields — default gracefully when absent in older JSON
        crossfadeEnabled = try c.decodeIfPresent(Bool.self, forKey: .crossfadeEnabled) ?? true
        crossfadeDuration = try c.decodeIfPresent(Double.self, forKey: .crossfadeDuration) ?? 4.0
        biometricCrossfadeEnabled = try c.decodeIfPresent(Bool.self, forKey: .biometricCrossfadeEnabled) ?? true
        allowCrossPlaylistRecommendations = try c.decodeIfPresent(Bool.self, forKey: .allowCrossPlaylistRecommendations) ?? false

        // Biometric signal toggles
        heartRateEnabled = try c.decodeIfPresent(Bool.self, forKey: .heartRateEnabled) ?? true
        hrvEnabled = try c.decodeIfPresent(Bool.self, forKey: .hrvEnabled) ?? true
        motionEnabled = try c.decodeIfPresent(Bool.self, forKey: .motionEnabled) ?? true
        sleepEnabled = try c.decodeIfPresent(Bool.self, forKey: .sleepEnabled) ?? true
        temperatureEnabled = try c.decodeIfPresent(Bool.self, forKey: .temperatureEnabled) ?? true
        biometricSensitivity = try c.decodeIfPresent(Double.self, forKey: .biometricSensitivity) ?? 0.5

        // AI preferences
        explorationBias = try c.decodeIfPresent(Double.self, forKey: .explorationBias) ?? 0.3
        bodyVsMindWeight = try c.decodeIfPresent(Double.self, forKey: .bodyVsMindWeight) ?? 0.5
        djAutonomy = try c.decodeIfPresent(Double.self, forKey: .djAutonomy) ?? 0.7
        aiVerbosity = try c.decodeIfPresent(Int.self, forKey: .aiVerbosity) ?? 1

        // Session defaults
        defaultSessionDuration = try c.decodeIfPresent(Int.self, forKey: .defaultSessionDuration) ?? 60
        defaultSessionIntent = try c.decodeIfPresent(String.self, forKey: .defaultSessionIntent) ?? "Auto-Detect"
    }

    // MARK: - Defaults

    public static var `default`: UserPreferences {
        UserPreferences()
    }
}

// MARK: - Validation

extension UserPreferences {
    /// Returns true if weights are properly balanced
    public var areWeightsValid: Bool {
        let totalWeight = bpmWeight + energyWeight + familiarityWeight + historicalWeight + contextWeight
        return totalWeight >= 0.95 && totalWeight <= 1.05
    }

    /// Normalizes weights to sum to 1.0
    public mutating func normalizeWeights() {
        let total = bpmWeight + energyWeight + familiarityWeight + historicalWeight + contextWeight
        guard total > 0 else { return }

        bpmWeight /= total
        energyWeight /= total
        familiarityWeight /= total
        historicalWeight /= total
        contextWeight /= total
    }

    /// Returns a validated copy with proper weight normalization
    public func validated() -> UserPreferences {
        var copy = self
        copy.normalizeWeights()

        // Clamp values to valid ranges
        copy.avoidRecentMinutes = max(0, min(480, copy.avoidRecentMinutes))
        copy.maxSameArtistInRow = max(1, min(10, copy.maxSameArtistInRow))
        copy.morningMaxBPM = max(60, min(200, copy.morningMaxBPM))
        copy.nightMaxBPM = max(40, min(200, copy.nightMaxBPM))
        copy.nightStartHour = max(18, min(23, copy.nightStartHour))
        copy.morningEndHour = max(5, min(12, copy.morningEndHour))
        copy.skipPenaltyWeight = max(0, min(1, copy.skipPenaltyWeight))
        copy.hrvResponseWeight = max(0, min(1, copy.hrvResponseWeight))
        copy.learningRate = max(0.05, min(0.5, copy.learningRate))
        copy.crossfadeDuration = max(1.0, min(10.0, copy.crossfadeDuration))
        copy.biometricSensitivity = max(0, min(1, copy.biometricSensitivity))
        copy.explorationBias = max(0, min(1, copy.explorationBias))
        copy.bodyVsMindWeight = max(0, min(1, copy.bodyVsMindWeight))
        copy.djAutonomy = max(0, min(1, copy.djAutonomy))
        copy.aiVerbosity = max(0, min(2, copy.aiVerbosity))
        copy.defaultSessionDuration = max(5, min(480, copy.defaultSessionDuration))

        return copy
    }
}

// MARK: - Persistence

extension UserPreferences {
    private static let userDefaultsKey = "com.y4sh.resonance.userPreferences"

    /// App Group UserDefaults suite for cross-target access (widgets, watch)
    private nonisolated(unsafe) static let defaults: UserDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard

    /// Saves preferences to App Group UserDefaults
    public func save() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        Self.defaults.set(data, forKey: Self.userDefaultsKey)
    }

    /// Loads preferences from App Group UserDefaults.
    /// Returns defaults if no saved preferences exist or decoding fails.
    public static func load() -> UserPreferences {
        guard let data = defaults.data(forKey: userDefaultsKey) else {
            return .default
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(UserPreferences.self, from: data)
        } catch {
            #if DEBUG
            print("UserPreferences: failed to decode saved preferences, using defaults: \(error)")
            #endif
            return .default
        }
    }

    /// Resets preferences to defaults
    public static func reset() {
        defaults.removeObject(forKey: userDefaultsKey)
    }
}

// MARK: - Presets

extension UserPreferences {
    /// Preset for focus-oriented music selection
    public static var focusPreset: UserPreferences {
        var prefs = UserPreferences()
        prefs.bpmWeight = 0.10
        prefs.energyWeight = 0.10
        prefs.familiarityWeight = 0.25
        prefs.contextWeight = 0.30
        prefs.nightMaxBPM = 90
        prefs.enableSmoothTransitions = true
        return prefs.validated()
    }

    /// Preset for workout-oriented music selection
    public static var workoutPreset: UserPreferences {
        var prefs = UserPreferences()
        prefs.bpmWeight = 0.30
        prefs.energyWeight = 0.35
        prefs.familiarityWeight = 0.10
        prefs.historicalWeight = 0.15
        prefs.contextWeight = 0.10
        prefs.morningMaxBPM = 180
        prefs.nightMaxBPM = 160
        return prefs.validated()
    }

    /// Preset for relaxation-oriented music selection
    public static var relaxationPreset: UserPreferences {
        var prefs = UserPreferences()
        prefs.energyWeight = 0.10
        prefs.historicalWeight = 0.35
        prefs.morningMaxBPM = 100
        prefs.nightMaxBPM = 80
        prefs.preferFamiliarInStress = true
        return prefs.validated()
    }
}
