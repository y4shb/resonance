//
//  WorkoutBPMAdvisor.swift
//  Resonance
//
//  Maps active workout types to target BPM ranges for music selection.
//  Used by the DecisionEngine to bias song scoring toward tempo ranges
//  that complement the user's current workout activity.
//  (Workstream 3.7)
//

#if os(iOS)

import Foundation
import HealthKit

// MARK: - Workout BPM Range

/// Target BPM range for a specific workout type.
struct WorkoutBPMRange: Sendable {
    let minBPM: Double
    let maxBPM: Double
    let idealBPM: Double

    /// Returns how well a given song BPM fits this workout range (0.0 - 1.0).
    func fitScore(for songBPM: Double) -> Double {
        guard songBPM > 0 else { return 0.5 } // Unknown BPM gets neutral score

        if songBPM >= minBPM && songBPM <= maxBPM {
            // Within range: score based on closeness to ideal
            let distance = abs(songBPM - idealBPM)
            let rangeWidth = maxBPM - minBPM
            guard rangeWidth > 0 else { return 1.0 }
            return max(0.5, 1.0 - (distance / rangeWidth) * 0.5)
        }

        // Outside range: penalize based on how far outside
        let outsideDistance: Double
        if songBPM < minBPM {
            outsideDistance = minBPM - songBPM
        } else {
            outsideDistance = songBPM - maxBPM
        }

        return max(0.0, 0.5 - (outsideDistance / 40.0))
    }
}

// MARK: - Workout BPM Advisor

/// Maps workout activity types to recommended music BPM ranges.
/// Consulted during song scoring to bias towards tempo-appropriate tracks.
final class WorkoutBPMAdvisor {

    // MARK: - BPM Range Lookup

    /// Returns the target BPM range for a given workout activity type.
    /// Returns nil for workout types where BPM matching is not beneficial
    /// (e.g., stretching, meditation).
    func targetBPMRange(
        for activityType: HKWorkoutActivityType
    ) -> WorkoutBPMRange? {
        switch activityType {
        // High-intensity cardio
        case .running:
            return WorkoutBPMRange(minBPM: 150, maxBPM: 180, idealBPM: 170)
        case .highIntensityIntervalTraining:
            return WorkoutBPMRange(minBPM: 140, maxBPM: 180, idealBPM: 160)

        // Moderate-intensity cardio
        case .cycling:
            return WorkoutBPMRange(minBPM: 120, maxBPM: 160, idealBPM: 140)
        case .elliptical:
            return WorkoutBPMRange(minBPM: 120, maxBPM: 150, idealBPM: 135)
        case .rowing:
            return WorkoutBPMRange(minBPM: 120, maxBPM: 150, idealBPM: 130)
        case .stairClimbing:
            return WorkoutBPMRange(minBPM: 120, maxBPM: 150, idealBPM: 135)

        // Low-to-moderate intensity
        case .walking:
            return WorkoutBPMRange(minBPM: 100, maxBPM: 130, idealBPM: 115)
        case .hiking:
            return WorkoutBPMRange(minBPM: 100, maxBPM: 130, idealBPM: 115)

        // Strength training
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return WorkoutBPMRange(minBPM: 110, maxBPM: 150, idealBPM: 130)
        case .coreTraining:
            return WorkoutBPMRange(minBPM: 100, maxBPM: 140, idealBPM: 120)

        // Dance
        case .dance:
            return WorkoutBPMRange(minBPM: 110, maxBPM: 140, idealBPM: 125)

        // Swimming: no headphones typically, but AirPods Pro can work
        case .swimming:
            return WorkoutBPMRange(minBPM: 120, maxBPM: 150, idealBPM: 135)

        // Mind-body: calm, slower tempo
        case .yoga:
            return WorkoutBPMRange(minBPM: 60, maxBPM: 90, idealBPM: 75)
        case .cooldown:
            return WorkoutBPMRange(minBPM: 70, maxBPM: 100, idealBPM: 85)

        // Default for other workout types
        default:
            return WorkoutBPMRange(minBPM: 110, maxBPM: 150, idealBPM: 130)
        }
    }

    /// Returns the target BPM range for a workout type name string.
    /// Used when the activity type comes from Watch biometric packets as a string.
    func targetBPMRange(forWorkoutName name: String) -> WorkoutBPMRange? {
        let lowercased = name.lowercased()

        if lowercased.contains("run") {
            return targetBPMRange(for: .running)
        } else if lowercased.contains("hiit") || lowercased.contains("interval") {
            return targetBPMRange(for: .highIntensityIntervalTraining)
        } else if lowercased.contains("cycl") || lowercased.contains("bike") {
            return targetBPMRange(for: .cycling)
        } else if lowercased.contains("walk") {
            return targetBPMRange(for: .walking)
        } else if lowercased.contains("swim") {
            return targetBPMRange(for: .swimming)
        } else if lowercased.contains("yoga") {
            return targetBPMRange(for: .yoga)
        } else if lowercased.contains("strength") || lowercased.contains("weight") {
            return targetBPMRange(for: .traditionalStrengthTraining)
        } else if lowercased.contains("dance") {
            return targetBPMRange(for: .dance)
        } else if lowercased.contains("row") {
            return targetBPMRange(for: .rowing)
        } else if lowercased.contains("cool") {
            return targetBPMRange(for: .cooldown)
        }

        // Default moderate workout range
        return WorkoutBPMRange(minBPM: 110, maxBPM: 150, idealBPM: 130)
    }
}

#endif
