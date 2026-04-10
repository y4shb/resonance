//
//  ScoringOverrides.swift
//  Resonance
//
//  Temporary scoring weight overrides for E3 (NL scoring adjustments).
//  Allows natural-language commands to tweak scoring weights for a
//  limited number of songs before reverting to user defaults.
//

import Foundation

/// Temporary overrides for scoring weights, applied by NL commands (E3).
///
/// When active, the overridden weights replace the corresponding
/// `UserPreferences` weights in the scorer for `remainingSongs` picks.
/// After the count expires, the decision engine reverts to default weights.
public struct ScoringOverrides: Sendable {
    /// Override for BPM weight (nil = use default)
    public var bpmWeight: Double?

    /// Override for energy weight (nil = use default)
    public var energyWeight: Double?

    /// Override for familiarity weight (nil = use default)
    public var familiarityWeight: Double?

    /// Override for historical weight (nil = use default)
    public var historicalWeight: Double?

    /// Override for context weight (nil = use default)
    public var contextWeight: Double?

    /// Override for exploration bias (nil = use default)
    public var explorationBias: Double?

    /// Number of songs remaining before this override expires.
    /// Decremented after each song selection. When 0, the override is cleared.
    public var remainingSongs: Int

    /// Human-readable description of what was requested (for UI/logging).
    public var description: String

    public init(
        bpmWeight: Double? = nil,
        energyWeight: Double? = nil,
        familiarityWeight: Double? = nil,
        historicalWeight: Double? = nil,
        contextWeight: Double? = nil,
        explorationBias: Double? = nil,
        remainingSongs: Int = 3,
        description: String = ""
    ) {
        self.bpmWeight = bpmWeight
        self.energyWeight = energyWeight
        self.familiarityWeight = familiarityWeight
        self.historicalWeight = historicalWeight
        self.contextWeight = contextWeight
        self.explorationBias = explorationBias
        self.remainingSongs = remainingSongs
        self.description = description
    }

    /// Whether this override has expired (no remaining songs).
    public var isExpired: Bool { remainingSongs <= 0 }

    /// Returns a copy with remainingSongs decremented by 1.
    public func decremented() -> ScoringOverrides {
        var copy = self
        copy.remainingSongs = max(0, copy.remainingSongs - 1)
        return copy
    }
}

/// Weather-based scoring modifiers (E2).
/// Provides target adjustments for BPM, energy, and valence based on weather conditions.
public struct WeatherModifiers: Sendable {
    /// Target BPM adjustment (added to base target)
    public var bpmAdjustment: Double

    /// Target energy adjustment (added to base target, clamped 0-1)
    public var energyAdjustment: Double

    /// Target valence adjustment (added to base valence target, clamped 0-1)
    public var valenceAdjustment: Double

    /// Blend weight (0.0-1.0) controlling how much weather modifies the score.
    /// Typically matches UserPreferences.weatherInfluenceWeight.
    public var weight: Double

    public init(
        bpmAdjustment: Double = 0.0,
        energyAdjustment: Double = 0.0,
        valenceAdjustment: Double = 0.0,
        weight: Double = 0.25
    ) {
        self.bpmAdjustment = bpmAdjustment
        self.energyAdjustment = energyAdjustment
        self.valenceAdjustment = valenceAdjustment
        self.weight = weight
    }
}
