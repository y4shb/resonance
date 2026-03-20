//
//  MoodPlaylist.swift
//  Resonance
//
//  Auto-generated mood-based playlists powered by audio feature predicates.
//  Each case defines a curated mix with an NSPredicate that filters the
//  user's song library by energy, valence, and instrumentalness.
//

import Foundation

// MARK: - Mood Playlist

/// Predefined mood playlists that Resonance generates automatically from
/// the user's library using audio-feature predicates.
///
/// Each case represents a curated mood mix with its own display metadata
/// (name, icon, color) and a Core Data `NSPredicate` that filters
/// the user's song library by energy, valence, and instrumentalness.
internal enum MoodPlaylist: String, CaseIterable, Identifiable, Hashable, Sendable {
    case relax
    case focus
    case energy
    case happy
    case melancholy
    case chill

    internal var id: String { rawValue }

    // MARK: - Display

    /// Human-readable name shown in the playlist browser.
    internal var displayName: String {
        switch self {
        case .relax:      return "Resonance - Relax"
        case .focus:      return "Resonance - Focus"
        case .energy:     return "Resonance - Energy"
        case .happy:      return "Resonance - Happy"
        case .melancholy: return "Resonance - Melancholy"
        case .chill:      return "Resonance - Chill"
        }
    }

    /// SF Symbol icon name for the playlist row.
    internal var icon: String {
        switch self {
        case .relax:      return "brain.head.profile"
        case .focus:      return "target"
        case .energy:     return "bolt.fill"
        case .happy:      return "sun.max.fill"
        case .melancholy: return "cloud.rain.fill"
        case .chill:      return "leaf.fill"
        }
    }

    /// Named accent color for the playlist row icon.
    internal var accentColor: String {
        switch self {
        case .relax:      return "teal"
        case .focus:      return "blue"
        case .energy:     return "red"
        case .happy:      return "yellow"
        case .melancholy: return "purple"
        case .chill:      return "cyan"
        }
    }

    // MARK: - Predicates

    /// Core Data predicate that filters `Song` entities matching this mood.
    ///
    /// Predicates reference the `Song` entity's audio-feature attributes:
    /// - `energyEstimate` (`Double`, 0-1)
    /// - `valence` (`Double`, 0-1)
    /// - `instrumentalness` (`Double`, 0-1)
    /// - `confidenceLevel` (`Double`, 0-1) -- only includes analyzed songs
    internal var predicate: NSPredicate {
        let analyzed = NSPredicate(format: "confidenceLevel > 0")

        let mood: NSPredicate
        switch self {
        case .relax:
            // Low energy, moderately positive valence
            mood = NSPredicate(
                format: "energyEstimate < %f AND valence > %f",
                Thresholds.relaxMaxEnergy, Thresholds.relaxMinValence
            )

        case .focus:
            // Low-to-moderate energy, high instrumentalness
            mood = NSPredicate(
                format: "energyEstimate >= %f AND energyEstimate <= %f AND instrumentalness >= %f",
                Thresholds.focusMinEnergy, Thresholds.focusMaxEnergy, Thresholds.focusMinInstrumentalness
            )

        case .energy:
            // High energy, moderate-to-high valence
            mood = NSPredicate(
                format: "energyEstimate > %f AND valence > %f",
                Thresholds.energyMinEnergy, Thresholds.energyMinValence
            )

        case .happy:
            // Moderate-to-high energy, high valence
            mood = NSPredicate(
                format: "energyEstimate >= %f AND valence > %f",
                Thresholds.happyMinEnergy, Thresholds.happyMinValence
            )

        case .melancholy:
            // Low-to-moderate energy, low valence
            mood = NSPredicate(
                format: "energyEstimate < %f AND valence < %f",
                Thresholds.melancholyMaxEnergy, Thresholds.melancholyMaxValence
            )

        case .chill:
            // Low-to-moderate energy, moderate valence
            mood = NSPredicate(
                format: "energyEstimate >= %f AND energyEstimate <= %f AND valence >= %f AND valence <= %f",
                Thresholds.chillMinEnergy, Thresholds.chillMaxEnergy,
                Thresholds.chillMinValence, Thresholds.chillMaxValence
            )
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: [analyzed, mood])
    }

    /// A short description shown below the playlist name.
    internal var subtitle: String {
        switch self {
        case .relax:      return "Calm tracks for unwinding"
        case .focus:      return "Instrumental grooves for deep work"
        case .energy:     return "High-energy bangers"
        case .happy:      return "Feel-good vibes"
        case .melancholy: return "Contemplative and introspective"
        case .chill:      return "Easy-going and mellow"
        }
    }
}

// MARK: - Predicate Thresholds

private extension MoodPlaylist {

    /// Named constants for the audio-feature thresholds used in mood predicates.
    enum Thresholds {
        static let relaxMaxEnergy: Double = 0.35
        static let relaxMinValence: Double = 0.35

        static let focusMinEnergy: Double = 0.2
        static let focusMaxEnergy: Double = 0.5
        static let focusMinInstrumentalness: Double = 0.4

        static let energyMinEnergy: Double = 0.7
        static let energyMinValence: Double = 0.4

        static let happyMinEnergy: Double = 0.45
        static let happyMinValence: Double = 0.65

        static let melancholyMaxEnergy: Double = 0.5
        static let melancholyMaxValence: Double = 0.35

        static let chillMinEnergy: Double = 0.15
        static let chillMaxEnergy: Double = 0.45
        static let chillMinValence: Double = 0.4
        static let chillMaxValence: Double = 0.7
    }
}
