//
//  SongFeatures.swift
//  Resonance
//
//  Audio features and metadata for a song
//

import Foundation

/// Audio features extracted or derived for a song
public struct SongFeatures: Codable, Sendable, Equatable {
    // MARK: - Audio Characteristics

    /// Tempo in beats per minute (0 if unknown)
    public var bpm: Double

    /// Energy estimate (0.0 - 1.0)
    /// Higher values represent more energetic, intense tracks
    public var energy: Double

    /// Acoustic density (0.0 - 1.0)
    /// How "full" the sound is - sparse to dense
    public var acousticDensity: Double

    /// Musical valence/positivity (0.0 - 1.0)
    /// 0.0 = sad/dark, 1.0 = happy/bright
    public var valence: Double

    /// Instrumentalness (0.0 - 1.0)
    /// How likely the track has no vocals
    public var instrumentalness: Double

    // MARK: - Metadata

    /// Song duration in seconds
    public var durationSeconds: Double

    /// Primary genre
    public var primaryGenre: String?

    /// All genre tags
    public var genres: [String]

    /// Release year
    public var releaseYear: Int?

    // MARK: - Feature Quality

    /// Whether features were extracted from audio analysis
    public var isAnalyzed: Bool

    /// Confidence in the feature values (0.0 - 1.0)
    public var confidence: Double

    /// When features were last updated
    public var lastUpdated: Date

    // MARK: - Initialization

    public init(
        bpm: Double = 0,
        energy: Double = 0.5,
        acousticDensity: Double = 0.5,
        valence: Double = 0.5,
        instrumentalness: Double = 0.5,
        durationSeconds: Double = 0,
        primaryGenre: String? = nil,
        genres: [String] = [],
        releaseYear: Int? = nil,
        isAnalyzed: Bool = false,
        confidence: Double = 0,
        lastUpdated: Date = Date()
    ) {
        self.bpm = bpm
        self.energy = energy
        self.acousticDensity = acousticDensity
        self.valence = valence
        self.instrumentalness = instrumentalness
        self.durationSeconds = durationSeconds
        self.primaryGenre = primaryGenre
        self.genres = genres
        self.releaseYear = releaseYear
        self.isAnalyzed = isAnalyzed
        self.confidence = confidence
        self.lastUpdated = lastUpdated
    }

    // MARK: - Factory

    public static var unknown: SongFeatures {
        SongFeatures()
    }
}

// MARK: - Computed Properties

extension SongFeatures {
    /// Formatted duration string (mm:ss)
    public var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Tempo category
    public var tempoCategory: TempoCategory {
        switch bpm {
        case ..<70: return .verySlow
        case 70..<90: return .slow
        case 90..<120: return .moderate
        case 120..<140: return .fast
        case 140..<160: return .veryFast
        default: return .extreme
        }
    }

    /// Energy category
    public var energyCategory: EnergyCategory {
        switch energy {
        case ..<0.2: return .veryLow
        case 0.2..<0.4: return .low
        case 0.4..<0.6: return .medium
        case 0.6..<0.8: return .high
        default: return .veryHigh
        }
    }

    /// Overall mood descriptor
    public var moodDescriptor: String {
        let energyLevel = energyCategory
        let isPositive = valence > 0.5

        switch (energyLevel, isPositive) {
        case (.veryLow, true): return "Peaceful"
        case (.veryLow, false): return "Melancholic"
        case (.low, true): return "Relaxed"
        case (.low, false): return "Sad"
        case (.medium, true): return "Pleasant"
        case (.medium, false): return "Moody"
        case (.high, true): return "Upbeat"
        case (.high, false): return "Intense"
        case (.veryHigh, true): return "Euphoric"
        case (.veryHigh, false): return "Aggressive"
        }
    }
}

// MARK: - Supporting Types

public enum TempoCategory: String, Codable, CaseIterable, Sendable {
    case verySlow = "very_slow"
    case slow = "slow"
    case moderate = "moderate"
    case fast = "fast"
    case veryFast = "very_fast"
    case extreme = "extreme"

    public var displayName: String {
        switch self {
        case .verySlow: return "Very Slow"
        case .slow: return "Slow"
        case .moderate: return "Moderate"
        case .fast: return "Fast"
        case .veryFast: return "Very Fast"
        case .extreme: return "Extreme"
        }
    }

    public var bpmRange: ClosedRange<Double> {
        switch self {
        case .verySlow: return 0...69
        case .slow: return 70...89
        case .moderate: return 90...119
        case .fast: return 120...139
        case .veryFast: return 140...159
        case .extreme: return 160...300
        }
    }
}

public enum EnergyCategory: String, Codable, CaseIterable, Sendable {
    case veryLow = "very_low"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"

    public var displayName: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
}

// MARK: - Genre Utilities

extension SongFeatures {
    /// Common genre categories for mapping
    public static let genreCategories: [String: [String]] = [
        "electronic": ["electronic", "edm", "house", "techno", "trance", "dubstep", "drum and bass"],
        "rock": ["rock", "alternative", "indie", "punk", "grunge"],
        "metal": ["metal", "metalcore", "death metal", "black metal", "heavy metal", "thrash", "doom"],
        "pop": ["pop", "dance pop", "synth pop", "electropop"],
        "hip-hop": ["hip-hop", "rap", "trap", "r&b"],
        "classical": ["classical", "orchestra", "symphony", "piano"],
        "jazz": ["jazz", "blues", "soul", "funk"],
        "ambient": ["ambient", "new age", "meditation", "chill"]
    ]

    /// Returns the broad genre category
    public var genreCategory: String? {
        for (category, keywords) in Self.genreCategories {
            for genre in genres {
                let lowercased = genre.lowercased()
                if keywords.contains(where: { lowercased.contains($0) }) {
                    return category
                }
            }
        }
        return nil
    }
}
