//
//  FeatureNormalizer.swift
//  Resonance
//
//  Normalizes feature values for relative comparison across a library.
//

import Foundation

/// Normalizes feature values for relative comparison across a library.
struct FeatureNormalizer {

    /// Normalizes BPM to 0.0-1.0 scale using provided min/max bounds.
    static func normalizeBPM(_ bpm: Double, libraryMin: Double = 60, libraryMax: Double = 180) -> Double {
        return normalize(bpm, min: libraryMin, max: libraryMax)
    }

    /// Clamps a value to the 0.0-1.0 range.
    static func clamp(_ value: Double) -> Double {
        return min(max(value, 0.0), 1.0)
    }

    /// Normalizes a value from an arbitrary range to 0.0-1.0.
    static func normalize(_ value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0.0 }
        return clamp((value - min) / (max - min))
    }
}
