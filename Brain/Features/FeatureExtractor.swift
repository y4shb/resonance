//
//  FeatureExtractor.swift
//  Resonance
//
//  Extracts and estimates audio features for songs using genre-based heuristics.
//  Since MusicKit does not expose BPM/energy/valence, this uses genre-to-feature
//  mapping tables to produce reasonable estimates.
//

import CoreData
import Foundation

/// Extracts and estimates audio features for songs using genre-based heuristics.
/// Since MusicKit does not expose BPM/energy/valence, this uses genre-to-feature mapping tables.
final class FeatureExtractor {

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Batch Extraction

    /// Extracts features for a batch of songs that need analysis.
    /// Fetches songs with bpm == 0 or confidenceLevel < 0.3, extracts features, saves.
    func extractFeaturesForPendingSongs(limit: Int = 50) async {
        let songRepository = SongRepository(persistence: persistence)
        let pendingSongs = songRepository.fetchSongsNeedingFeatures(limit: limit)

        guard !pendingSongs.isEmpty else {
            logDebug("No songs pending feature extraction", category: .background)
            return
        }

        logInfo("Starting feature extraction for \(pendingSongs.count) songs", category: .background)

        let objectIDs = pendingSongs.map { $0.objectID }

        do {
            try await persistence.performBackgroundTask { context in
                var processedCount = 0

                for objectID in objectIDs {
                    do {
                        guard let song = try context.existingObject(with: objectID) as? Song else {
                            logWarning(
                                "FeatureExtractor: song not found in background context for objectID \(objectID)",
                                category: .background
                            )
                            continue
                        }

                        self.extractFeatures(for: song, in: context)
                        processedCount += 1
                    } catch {
                        logError(
                            "FeatureExtractor: failed to fetch song for feature extraction",
                            error: error,
                            category: .background
                        )
                    }
                }

                if context.hasChanges {
                    try context.save()
                }

                logInfo(
                    "Feature extraction complete — processed \(processedCount)/\(objectIDs.count) songs",
                    category: .background
                )
            }
        } catch {
            logError(
                "FeatureExtractor: background task failed during feature extraction",
                error: error,
                category: .background
            )
        }
    }

    // MARK: - Single Song Extraction

    /// Extracts features for a single song in the given context.
    func extractFeatures(for song: Song, in context: NSManagedObjectContext) {
        let genres: [String]
        if let raw = song.genreNames as? [String] {
            genres = raw
        } else {
            genres = []
        }

        let genreCategory = matchGenreCategory(genres: genres)

        let bpm = estimateBPM(genreCategory: genreCategory)
        let energy = estimateEnergy(genreCategory: genreCategory, bpm: bpm)
        let valence = estimateValence(genreCategory: genreCategory)
        let instrumentalness = estimateInstrumentalness(genreCategory: genreCategory)
        let acousticDensity = estimateAcousticDensity(genreCategory: genreCategory, energy: energy)

        song.bpm = bpm
        song.energyEstimate = energy
        song.valence = valence
        song.instrumentalness = instrumentalness
        song.acousticDensity = acousticDensity
        song.confidenceLevel = 0.4 // genre-based confidence

        // Derived scores
        let bpmNormalized = min(max((bpm - 60.0) / 120.0, 0.0), 1.0)
        song.calmScore = (1.0 - energy) * 0.5 + (1.0 - bpmNormalized) * 0.3 + instrumentalness * 0.2
        song.focusScore = instrumentalness * 0.4 + (1.0 - energy) * 0.3 + acousticDensity * 0.3
        song.activationScore = energy * 0.5 + bpmNormalized * 0.3 + valence * 0.2

        logDebug(
            "Extracted features for '\(song.title)' — genre: \(genreCategory ?? "unknown"), " +
            "bpm: \(bpm), energy: \(energy), valence: \(valence), confidence: 0.4",
            category: .background
        )
    }

    // MARK: - Genre-to-Feature Mappings

    static let genreBPM: [String: Double] = [
        "ambient": 70, "classical": 80, "jazz": 100,
        "pop": 120, "rock": 130, "electronic": 128,
        "hip-hop": 90, "metal": 140
    ]

    static let genreEnergy: [String: Double] = [
        "ambient": 0.15, "classical": 0.25, "jazz": 0.35,
        "pop": 0.55, "rock": 0.70, "electronic": 0.65,
        "hip-hop": 0.50, "metal": 0.85
    ]

    static let genreValence: [String: Double] = [
        "ambient": 0.40, "classical": 0.50, "jazz": 0.55,
        "pop": 0.70, "rock": 0.50, "electronic": 0.55,
        "hip-hop": 0.45, "metal": 0.30
    ]

    static let genreInstrumentalness: [String: Double] = [
        "ambient": 0.85, "classical": 0.90, "jazz": 0.40,
        "pop": 0.05, "rock": 0.15, "electronic": 0.60,
        "hip-hop": 0.05, "metal": 0.20
    ]

    // MARK: - Private Estimation Methods

    /// Matches genre strings against SongFeatures.genreCategories to find the broad category.
    private func matchGenreCategory(genres: [String]) -> String? {
        for genre in genres {
            let lowercased = genre.lowercased()
            for (category, keywords) in SongFeatures.genreCategories {
                if keywords.contains(where: { lowercased.contains($0) }) {
                    return category
                }
            }
        }
        return nil
    }

    private func estimateBPM(genreCategory: String?) -> Double {
        guard let category = genreCategory else { return 100.0 }
        return FeatureExtractor.genreBPM[category] ?? 100.0
    }

    private func estimateEnergy(genreCategory: String?, bpm: Double) -> Double {
        guard let category = genreCategory else { return 0.5 }
        return FeatureExtractor.genreEnergy[category] ?? 0.5
    }

    private func estimateValence(genreCategory: String?) -> Double {
        guard let category = genreCategory else { return 0.5 }
        return FeatureExtractor.genreValence[category] ?? 0.5
    }

    private func estimateInstrumentalness(genreCategory: String?) -> Double {
        guard let category = genreCategory else { return 0.3 }
        return FeatureExtractor.genreInstrumentalness[category] ?? 0.3
    }

    private func estimateAcousticDensity(genreCategory: String?, energy: Double) -> Double {
        guard genreCategory != nil else { return 0.5 }
        // Acoustic density correlates positively with energy for most genres.
        // We clamp the result to [0, 1].
        return min(max(energy * 0.8 + 0.1, 0.0), 1.0)
    }
}
