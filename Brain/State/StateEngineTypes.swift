//
//  StateEngineTypes.swift
//  Resonance
//
//  Data types used by the StateEngine: ManualMoodInput and EstimateResult.
//  Extracted from StateEngine.swift to keep files under the 500-line limit.
//

#if os(iOS)

import Foundation

// MARK: - Manual Mood Input

/// Manual mood input from user (iOS slider or Watch 3-tap).
/// Decays over `StateEngineConstants.manualMoodDecayMinutes`.
struct ManualMoodInput: Sendable {
    let energy: Double      // 0.0 = exhausted, 1.0 = energized
    let valence: Double     // 0.0 = negative, 1.0 = positive
    let timestamp: Date

    /// Returns the decay-adjusted weight (1.0 when fresh, 0.0 after decay period).
    var currentWeight: Double {
        let ageMinutes = Date().timeIntervalSince(timestamp) / 60.0
        let decayMinutes = Double(StateEngineConstants.manualMoodDecayMinutes)
        guard ageMinutes < decayMinutes else { return 0.0 }
        return 1.0 - (ageMinutes / decayMinutes)
    }

    /// Whether this input is still active (within decay window).
    var isActive: Bool {
        currentWeight > 0.0
    }
}

// MARK: - Estimate Result

/// Intermediate result with value and confidence.
struct EstimateResult: Sendable {
    let value: Double
    let confidence: Double
}

#endif
