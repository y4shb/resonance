//
//  MoodTrajectory.swift
//  Resonance
//
//  Describes a user's desired mood journey from a current emotional state
//  to a target state. Used by SessionPlanner to build iso-principle arcs
//  and by MoodTabView for journey progress visualization.
//

import Foundation

// MARK: - Mood Trajectory

/// A mood journey from the user's current energy/valence to a desired target.
public struct MoodTrajectory: Codable, Sendable, Equatable {
    /// Current energy level (0.0 = exhausted, 1.0 = energized).
    public let currentEnergy: Double
    /// Current valence level (0.0 = negative, 1.0 = positive).
    public let currentValence: Double
    /// Target energy level the user wants to reach.
    public let targetEnergy: Double
    /// Target valence level the user wants to reach.
    public let targetValence: Double
    /// When this trajectory was created.
    public let timestamp: Date

    // MARK: - Computed Properties

    /// Euclidean distance between current and target mood points.
    public var gapMagnitude: Double {
        let dEnergy = targetEnergy - currentEnergy
        let dValence = targetValence - currentValence
        return (dEnergy * dEnergy + dValence * dValence).squareRoot()
    }

    /// Estimated number of songs needed to reach the target.
    ///
    /// Each song can shift mood by approximately `moodShiftPerSong` units.
    /// Result is clamped between `minSongsInJourney` and `maxSongsInJourney`.
    public var estimatedSongsToTarget: Int {
        guard gapMagnitude > 0 else { return Self.minSongsInJourney }
        let rawCount = Int(ceil(gapMagnitude / Self.moodShiftPerSong))
        return min(max(rawCount, Self.minSongsInJourney), Self.maxSongsInJourney)
    }

    // MARK: - Constants

    /// Approximate mood shift a single song can produce (in energy/valence units).
    private static let moodShiftPerSong: Double = 0.15

    /// Minimum number of songs in a mood journey.
    private static let minSongsInJourney: Int = 1

    /// Maximum number of songs in a mood journey.
    private static let maxSongsInJourney: Int = 10

    // MARK: - Interpolation

    /// Returns the target energy at a given step along the trajectory.
    /// - Parameters:
    ///   - step: Current step (0-based).
    ///   - totalSteps: Total number of steps in the journey.
    /// - Returns: Interpolated energy value clamped to 0.0-1.0.
    public func targetEnergyAtStep(step: Int, totalSteps: Int) -> Double {
        let progress = interpolationProgress(step: step, totalSteps: totalSteps)
        return clamp(currentEnergy + (targetEnergy - currentEnergy) * progress)
    }

    /// Returns the target valence at a given step along the trajectory.
    /// - Parameters:
    ///   - step: Current step (0-based).
    ///   - totalSteps: Total number of steps in the journey.
    /// - Returns: Interpolated valence value clamped to 0.0-1.0.
    public func targetValenceAtStep(step: Int, totalSteps: Int) -> Double {
        let progress = interpolationProgress(step: step, totalSteps: totalSteps)
        return clamp(currentValence + (targetValence - currentValence) * progress)
    }

    // MARK: - Private Helpers

    private func interpolationProgress(step: Int, totalSteps: Int) -> Double {
        guard totalSteps > 1 else { return 1.0 }
        let clampedStep = min(max(step, 0), totalSteps)
        return Double(clampedStep) / Double(totalSteps)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}
