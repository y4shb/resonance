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
        backupToiCloud: Bool = true
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
        copy.nightMaxBPM = max(40, min(150, copy.nightMaxBPM))
        copy.nightStartHour = max(18, min(23, copy.nightStartHour))
        copy.morningEndHour = max(5, min(12, copy.morningEndHour))
        copy.skipPenaltyWeight = max(0, min(1, copy.skipPenaltyWeight))
        copy.hrvResponseWeight = max(0, min(1, copy.hrvResponseWeight))
        copy.learningRate = max(0.05, min(0.5, copy.learningRate))

        return copy
    }
}

// MARK: - Persistence

extension UserPreferences {
    private static let userDefaultsKey = "com.y4sh.resonance.userPreferences"

    /// App Group UserDefaults suite for cross-target access (widgets, watch)
    private static let defaults: UserDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard

    /// Saves preferences to App Group UserDefaults
    public func save() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        Self.defaults.set(data, forKey: Self.userDefaultsKey)
    }

    /// Loads preferences from App Group UserDefaults
    public static func load() -> UserPreferences {
        guard let data = defaults.data(forKey: userDefaultsKey) else {
            return .default
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(UserPreferences.self, from: data)
        } catch {
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
