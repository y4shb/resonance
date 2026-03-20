//
//  EmotionCategory.swift
//  Resonance
//
//  Classifies songs into emotion categories based on energy and valence features.
//  Used by the mood donut chart, auto-generated mood playlists, and library analysis.
//

import SwiftUI

// MARK: - Emotion Category

/// Discrete emotion categories derived from the energy-valence plane.
/// Each category maps to a region of the 2D feature space and carries
/// display metadata (name, color, hex) for the mood chart.
public enum EmotionCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case happy
    case euphoric
    case energetic
    case calm
    case peaceful
    case focused
    case melancholy
    case sad
    case intense
    case chill

    public var id: String { rawValue }

    // MARK: - Display

    public var displayName: String {
        switch self {
        case .happy:      return "Happy"
        case .euphoric:   return "Euphoric"
        case .energetic:  return "Energetic"
        case .calm:       return "Calm"
        case .peaceful:   return "Peaceful"
        case .focused:    return "Focused"
        case .melancholy: return "Melancholy"
        case .sad:        return "Sad"
        case .intense:    return "Intense"
        case .chill:      return "Chill"
        }
    }

    // MARK: - Colors

    /// Hex color string for chart visualization and cross-platform serialization.
    public var colorHex: String {
        switch self {
        case .happy:      return "#FFD700"  // Gold
        case .euphoric:   return "#FF6B00"  // Vivid orange
        case .energetic:  return "#FF4500"  // Orange-red
        case .calm:       return "#4ECDC4"  // Teal
        case .peaceful:   return "#98FB98"  // Pale green
        case .focused:    return "#45B7D1"  // Steel blue
        case .melancholy: return "#708090"  // Slate gray
        case .sad:        return "#7B68EE"  // Medium slate blue
        case .intense:    return "#DC143C"  // Crimson
        case .chill:      return "#20B2AA"  // Light sea green
        }
    }

    public var color: Color {
        switch self {
        case .happy:      return Color.yellow
        case .euphoric:   return Color.orange
        case .energetic:  return Color.red
        case .calm:       return Color.teal
        case .peaceful:   return Color.green
        case .focused:    return Color.blue
        case .melancholy: return Color.indigo
        case .sad:        return Color.purple
        case .intense:    return Color.pink
        case .chill:      return Color.cyan
        }
    }

    // MARK: - Feature Ranges

    /// Expected energy range for songs in this category (0.0 - 1.0).
    public var energyRange: ClosedRange<Double> {
        switch self {
        case .happy:      return 0.45...0.70
        case .euphoric:   return 0.70...1.00
        case .energetic:  return 0.65...1.00
        case .calm:       return 0.10...0.40
        case .peaceful:   return 0.00...0.30
        case .focused:    return 0.20...0.50
        case .melancholy: return 0.10...0.45
        case .sad:        return 0.00...0.35
        case .intense:    return 0.70...1.00
        case .chill:      return 0.15...0.45
        }
    }

    /// Expected valence range for songs in this category (0.0 - 1.0).
    public var valenceRange: ClosedRange<Double> {
        switch self {
        case .happy:      return 0.60...1.00
        case .euphoric:   return 0.65...1.00
        case .energetic:  return 0.40...0.70
        case .calm:       return 0.40...0.65
        case .peaceful:   return 0.55...1.00
        case .focused:    return 0.35...0.60
        case .melancholy: return 0.15...0.40
        case .sad:        return 0.00...0.30
        case .intense:    return 0.00...0.40
        case .chill:      return 0.45...0.70
        }
    }

    // MARK: - Classification

    /// Classifies a song into an emotion category based on its audio features.
    ///
    /// Uses a nearest-centroid approach: computes the distance from the
    /// (energy, valence) point to each category's centroid and returns the
    /// closest match.
    ///
    /// - Parameters:
    ///   - energy: Energy estimate in the range 0.0 - 1.0.
    ///   - valence: Valence estimate in the range 0.0 - 1.0.
    /// - Returns: The best-matching `EmotionCategory`.
    public static func classify(energy: Double, valence: Double) -> EmotionCategory {
        let clampedEnergy = min(max(energy, 0), 1)
        let clampedValence = min(max(valence, 0), 1)

        var bestCategory: EmotionCategory = .chill
        var bestDistance = Double.greatestFiniteMagnitude

        for category in allCases {
            let centroidEnergy = (category.energyRange.lowerBound + category.energyRange.upperBound) / 2.0
            let centroidValence = (category.valenceRange.lowerBound + category.valenceRange.upperBound) / 2.0

            let dEnergy = clampedEnergy - centroidEnergy
            let dValence = clampedValence - centroidValence
            let distance = dEnergy * dEnergy + dValence * dValence

            if distance < bestDistance {
                bestDistance = distance
                bestCategory = category
            }
        }

        return bestCategory
    }
}
