//
//  CircadianEnergyModifier.swift
//  Resonance
//
//  Extension on CircadianProfileManager providing energy modifiers.
//  Computes a circadian-aware energy adjustment by normalizing the user's
//  learned heart rate curve, blending with the static fallback based on
//  profile confidence. Ensures zero behavioral change on day one.
//

import Foundation

// MARK: - Circadian Energy Modifier

extension CircadianProfileManager {

    /// Returns a learned energy modifier for the given hour based on the user's
    /// circadian HR profile. Normalizes HR deviation from the daily mean into
    /// the range -maxEnergyModifier...+maxEnergyModifier.
    ///
    /// - Parameter hour: Hour of day (0-23).
    /// - Returns: Energy modifier in the range -0.2...+0.2, or 0.0 if no data.
    func circadianEnergyModifier(forHour hour: Int) -> Double {
        guard let profile = currentProfile else {
            return 0.0
        }
        return Self.circadianEnergyModifierFromProfile(profile, forHour: hour)
    }

    /// Pure computation of the learned energy modifier from an already-captured
    /// profile snapshot. Does not acquire any locks.
    ///
    /// - Parameters:
    ///   - profile: A snapshot of the circadian profile.
    ///   - hour: Hour of day (0-23).
    /// - Returns: Energy modifier in the range -0.2...+0.2, or 0.0 if no data.
    private static func circadianEnergyModifierFromProfile(
        _ profile: CircadianProfile,
        forHour hour: Int
    ) -> Double {
        guard let hrForHour = profile.hourlyHeartRate[hour],
              let avgHR = profile.overallHeartRateAverage,
              avgHR > 0 else {
            return 0.0
        }

        // Deviation as a fraction of the daily mean
        let deviation = (hrForHour - avgHR) / avgHR

        // Clamp to the maximum modifier range
        let maxMod = CircadianConstants.maxEnergyModifier
        return max(-maxMod, min(maxMod, deviation))
    }

    /// Returns the static (population-level) energy modifier based on typical
    /// energy patterns throughout the day. This is the existing behavior before
    /// circadian personalization, preserved as a fallback.
    ///
    /// - Parameter hour: Hour of day (0-23).
    /// - Returns: Energy modifier matching the original static switch statement.
    static func staticEnergyModifier(forHour hour: Int) -> Double {
        switch hour {
        case 6..<10:
            return 0.1
        case 10..<14:
            return 0.15
        case 14..<16:
            return -0.05
        case 22..<24, 0..<6:
            return -0.15
        default:
            return 0.0
        }
    }

    /// Returns a blended energy modifier that transitions from the static fallback
    /// to the learned circadian model as profile confidence increases.
    ///
    /// When confidence is 0.0 (no data), returns the static modifier exactly.
    /// When confidence is 1.0 (21+ days of full data), returns the learned modifier.
    ///
    /// Thread-safe: captures the profile via the thread-safe `currentProfile`
    /// accessor in a single call, then performs all computation on the snapshot.
    /// This avoids the TOCTOU race where the profile could change between
    /// reading confidence and computing the learned modifier.
    ///
    /// - Parameter hour: Hour of day (0-23).
    /// - Returns: Blended energy modifier in the range -0.2...+0.2.
    func blendedEnergyModifier(forHour hour: Int) -> Double {
        // Single lock acquisition via the thread-safe currentProfile accessor.
        // All subsequent computation uses this snapshot only.
        guard let profile = currentProfile, profile.isMature else {
            return Self.staticEnergyModifier(forHour: hour)
        }

        let learned = Self.circadianEnergyModifierFromProfile(profile, forHour: hour)
        let fallback = Self.staticEnergyModifier(forHour: hour)
        return learned * profile.confidence + fallback * (1.0 - profile.confidence)
    }
}
