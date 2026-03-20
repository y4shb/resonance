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
    /// Uses a tiered approach: genre heuristics as baseline, then attempts
    /// ML prediction via AudioFeaturePredictor for higher confidence.
    func extractFeatures(for song: Song, in context: NSManagedObjectContext) {
        let genres: [String]
        if let raw = song.genreNames {
            genres = raw
        } else {
            genres = []
        }

        let genreCategory = matchGenreCategory(genres: genres)

        // Step 1: Genre-based estimates (baseline, confidence 0.4)
        let genreBpm = estimateBPM(genreCategory: genreCategory)
        let genreEnergy = estimateEnergy(genreCategory: genreCategory, bpm: genreBpm)
        let genreValence = estimateValence(genreCategory: genreCategory)
        let genreInstrumentalness = estimateInstrumentalness(genreCategory: genreCategory)

        // Step 2: Attempt ML / enhanced heuristic prediction
        let blended = blendPredictions(
            song: song,
            genres: genres,
            genreBpm: genreBpm,
            genreEnergy: genreEnergy,
            genreValence: genreValence,
            genreInstrumentalness: genreInstrumentalness
        )

        let bpm = blended.bpm
        let energy = blended.energy
        let valence = blended.valence
        let instrumentalness = blended.instrumentalness
        let confidence = blended.confidence

        let acousticDensity = estimateAcousticDensity(genreCategory: genreCategory, energy: energy)
        let hasVocals = estimateHasVocals(instrumentalness: instrumentalness)

        song.bpm = bpm
        song.energyEstimate = energy
        song.valence = valence
        song.instrumentalness = instrumentalness
        song.acousticDensity = acousticDensity
        song.confidenceLevel = confidence

        // Derived scores -- vocal tracks penalized for focus
        let bpmNormalized = min(max((bpm - 60.0) / 120.0, 0.0), 1.0)
        song.calmScore = (1.0 - energy) * 0.5 + (1.0 - bpmNormalized) * 0.3 + instrumentalness * 0.2
        let vocalPenalty = hasVocals ? 0.15 : 0.0
        song.focusScore = max(0.0,
            instrumentalness * 0.4 + (1.0 - energy) * 0.3 + (1.0 - acousticDensity) * 0.3 - vocalPenalty
        )
        song.activationScore = energy * 0.5 + bpmNormalized * 0.3 + valence * 0.2

        logDebug(
            "Extracted features for '\(song.title ?? "unknown")' — genre: \(genreCategory ?? "unknown"), " +
            "bpm: \(bpm), energy: \(energy), valence: \(valence), hasVocals: \(hasVocals), " +
            "confidence: \(confidence)",
            category: .background
        )
    }

    // MARK: - ML Prediction Blending

    /// Blends genre-based estimates with ML or enhanced heuristic predictions.
    ///
    /// Confidence tiers:
    /// - 0.65: ML model available and prediction succeeded (blend: 35% genre + 65% ML)
    /// - 0.45: Enhanced heuristics only (blend: 55% genre + 45% heuristic)
    /// - 0.40: Genre-only fallback (no blending)
    private func blendPredictions(
        song: Song,
        genres: [String],
        genreBpm: Double,
        genreEnergy: Double,
        genreValence: Double,
        genreInstrumentalness: Double
    ) -> (bpm: Double, energy: Double, valence: Double, instrumentalness: Double, confidence: Double) {
        #if os(iOS)
        let primaryGenre = genres.first ?? "unknown"

        // Extract release year from song's releaseDate
        let releaseYear: Int?
        if let releaseDate = song.releaseDate {
            releaseYear = Calendar.current.component(.year, from: releaseDate)
        } else {
            releaseYear = nil
        }

        // Build prediction input from song metadata.
        // trackNumber and contentRating may not be in the Core Data schema,
        // so we check the entity description before accessing via KVC.
        let entityAttributes = song.entity.attributesByName
        let trackNumber: Int
        if entityAttributes["trackNumber"] != nil,
           let value = song.value(forKey: "trackNumber") as? Int {
            trackNumber = value
        } else {
            trackNumber = 1
        }
        let isExplicit: Bool
        if entityAttributes["contentRating"] != nil,
           let rating = song.value(forKey: "contentRating") as? String {
            isExplicit = rating == "explicit"
        } else {
            isExplicit = false
        }

        let input = AudioFeaturePredictionInput(
            genre: primaryGenre,
            durationSeconds: song.durationSeconds,
            releaseYear: releaseYear,
            artistName: song.artistName ?? "",
            albumTitle: song.albumName ?? "",
            genreCount: genres.count,
            trackNumber: trackNumber,
            isExplicit: isExplicit
        )

        let prediction = AudioFeaturePredictor.shared.predict(input: input)

        if prediction.confidence >= 0.65 {
            // ML model prediction: blend 35% genre + 65% ML
            return (
                bpm: genreBpm * 0.35 + prediction.bpm * 0.65,
                energy: genreEnergy * 0.35 + prediction.energy * 0.65,
                valence: genreValence * 0.35 + prediction.valence * 0.65,
                instrumentalness: genreInstrumentalness * 0.35 + prediction.instrumentalness * 0.65,
                confidence: 0.65
            )
        } else if prediction.confidence >= 0.45 {
            // Enhanced heuristics: blend 55% genre + 45% heuristic
            return (
                bpm: genreBpm * 0.55 + prediction.bpm * 0.45,
                energy: genreEnergy * 0.55 + prediction.energy * 0.45,
                valence: genreValence * 0.55 + prediction.valence * 0.45,
                instrumentalness: genreInstrumentalness * 0.55 + prediction.instrumentalness * 0.45,
                confidence: 0.45
            )
        }
        #endif

        // Genre-only fallback
        return (
            bpm: genreBpm,
            energy: genreEnergy,
            valence: genreValence,
            instrumentalness: genreInstrumentalness,
            confidence: 0.4
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
        let genreEnergy = FeatureExtractor.genreEnergy[category] ?? 0.5
        // Factor in BPM: higher BPM tends to increase perceived energy
        let bpmFactor = min(max((bpm - 60.0) / 120.0, 0.0), 1.0)
        return genreEnergy * 0.7 + bpmFactor * 0.3
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

    /// Estimates whether a track has vocals based on instrumentalness.
    /// Tracks with instrumentalness < 0.5 are assumed to have vocals.
    private func estimateHasVocals(instrumentalness: Double) -> Bool {
        return instrumentalness < 0.5
    }
}
