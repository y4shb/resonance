//
//  AudioFeaturePredictor.swift
//  Resonance
//
//  Core ML model wrapper for predicting audio features from metadata.
//  Uses a tabular regressor trained on the Free Music Archive (FMA) dataset
//  to predict BPM, energy, valence, and instrumentalness from genre,
//  duration, and other metadata available via MusicKit.
//
//  This is a bridge between the genre-heuristic approach (0.4 confidence)
//  and full audio analysis (0.85 confidence), operating at 0.65 confidence.
//

#if os(iOS)

import CoreML
import Foundation

// MARK: - Prediction Input

/// Input features for the audio feature prediction model.
struct AudioFeaturePredictionInput {
    /// Primary genre (e.g., "pop", "rock", "electronic")
    let genre: String

    /// Track duration in seconds
    let durationSeconds: Double

    /// Release year (if available)
    let releaseYear: Int?

    /// Artist name (for artist-specific patterns)
    let artistName: String

    /// Album title (for album-level coherence)
    let albumTitle: String
}

// MARK: - Prediction Output

/// Predicted audio features with confidence scores.
struct AudioFeaturePrediction {
    let bpm: Double
    let energy: Double
    let valence: Double
    let instrumentalness: Double
    let confidence: Double  // 0.65 for ML predictions (between heuristic 0.4 and audio analysis 0.85)
}

// MARK: - Audio Feature Predictor

/// Predicts audio features using a Core ML tabular regressor.
/// Falls back to enhanced genre heuristics when the model is not available.
final class AudioFeaturePredictor {

    // MARK: - Singleton

    static let shared = AudioFeaturePredictor()

    // MARK: - Model State

    private var model: MLModel?
    private var isModelLoaded = false

    // MARK: - Initialization

    private init() {
        loadModel()
    }

    // MARK: - Model Loading

    private func loadModel() {
        // Look for a compiled Core ML model in the app bundle
        guard let modelURL = Bundle.main.url(forResource: "AudioFeatureRegressor", withExtension: "mlmodelc") else {
            logInfo("AudioFeatureRegressor.mlmodelc not found in bundle; using enhanced heuristics", category: .background)
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine  // Prefer Neural Engine for efficiency
            model = try MLModel(contentsOf: modelURL, configuration: config)
            isModelLoaded = true
            logInfo("AudioFeatureRegressor Core ML model loaded successfully", category: .background)
        } catch {
            logError("Failed to load AudioFeatureRegressor model", error: error, category: .background)
        }
    }

    // MARK: - Prediction

    /// Predicts audio features for a song from its metadata.
    func predict(input: AudioFeaturePredictionInput) -> AudioFeaturePrediction {
        if isModelLoaded, let model = model {
            return predictWithModel(model: model, input: input)
        }

        // Fallback to enhanced genre heuristics
        return predictWithEnhancedHeuristics(input: input)
    }

    // MARK: - Core ML Prediction

    private func predictWithModel(model: MLModel, input: AudioFeaturePredictionInput) -> AudioFeaturePrediction {
        do {
            let featureProvider = try MLDictionaryFeatureProvider(dictionary: [
                "genre": MLFeatureValue(string: input.genre),
                "duration": MLFeatureValue(double: input.durationSeconds),
                "year": MLFeatureValue(double: Double(input.releaseYear ?? 2020)),
            ])

            let prediction = try model.prediction(from: featureProvider)

            let bpm = prediction.featureValue(for: "bpm")?.doubleValue ?? 120.0
            let energy = prediction.featureValue(for: "energy")?.doubleValue ?? 0.5
            let valence = prediction.featureValue(for: "valence")?.doubleValue ?? 0.5
            let instrumentalness = prediction.featureValue(for: "instrumentalness")?.doubleValue ?? 0.3

            return AudioFeaturePrediction(
                bpm: min(220, max(40, bpm)),
                energy: min(1.0, max(0.0, energy)),
                valence: min(1.0, max(0.0, valence)),
                instrumentalness: min(1.0, max(0.0, instrumentalness)),
                confidence: 0.65
            )
        } catch {
            logError("Core ML prediction failed, using heuristics", error: error, category: .background)
            return predictWithEnhancedHeuristics(input: input)
        }
    }

    // MARK: - Enhanced Heuristics (Fallback)

    /// Enhanced genre heuristics that also consider duration and era.
    private func predictWithEnhancedHeuristics(input: AudioFeaturePredictionInput) -> AudioFeaturePrediction {
        let genreFeatures = genreLookup(input.genre)

        // Duration-based adjustments
        var bpm = genreFeatures.bpm
        var energy = genreFeatures.energy

        // Shorter tracks tend to be more energetic (singles vs album tracks)
        if input.durationSeconds < 180 {
            energy = min(1.0, energy + 0.05)
        } else if input.durationSeconds > 360 {
            energy = max(0.0, energy - 0.05)
            // Long tracks often have lower BPM (prog rock, ambient)
            bpm = max(60, bpm - 10)
        }

        // Era-based adjustments
        if let year = input.releaseYear {
            if year >= 2015 {
                // Modern production tends toward higher energy
                energy = min(1.0, energy + 0.03)
            } else if year < 1980 {
                // Pre-1980 music tends toward more acoustic
                energy = max(0.0, energy - 0.05)
            }
        }

        return AudioFeaturePrediction(
            bpm: bpm,
            energy: energy,
            valence: genreFeatures.valence,
            instrumentalness: genreFeatures.instrumentalness,
            confidence: 0.45  // Slightly better than raw genre lookup (0.4)
        )
    }

    // MARK: - Genre Lookup Table

    private struct GenreFeatures {
        let bpm: Double
        let energy: Double
        let valence: Double
        let instrumentalness: Double
    }

    private func genreLookup(_ genre: String) -> GenreFeatures {
        let normalized = genre.lowercased().trimmingCharacters(in: .whitespaces)

        let table: [String: GenreFeatures] = [
            "ambient": GenreFeatures(bpm: 70, energy: 0.15, valence: 0.40, instrumentalness: 0.85),
            "classical": GenreFeatures(bpm: 80, energy: 0.25, valence: 0.50, instrumentalness: 0.90),
            "jazz": GenreFeatures(bpm: 100, energy: 0.35, valence: 0.55, instrumentalness: 0.40),
            "acoustic": GenreFeatures(bpm: 95, energy: 0.30, valence: 0.60, instrumentalness: 0.30),
            "folk": GenreFeatures(bpm: 100, energy: 0.35, valence: 0.55, instrumentalness: 0.20),
            "country": GenreFeatures(bpm: 110, energy: 0.45, valence: 0.65, instrumentalness: 0.10),
            "r&b": GenreFeatures(bpm: 85, energy: 0.40, valence: 0.55, instrumentalness: 0.10),
            "soul": GenreFeatures(bpm: 90, energy: 0.40, valence: 0.60, instrumentalness: 0.10),
            "pop": GenreFeatures(bpm: 120, energy: 0.55, valence: 0.70, instrumentalness: 0.05),
            "indie": GenreFeatures(bpm: 115, energy: 0.45, valence: 0.50, instrumentalness: 0.15),
            "alternative": GenreFeatures(bpm: 118, energy: 0.50, valence: 0.45, instrumentalness: 0.15),
            "rock": GenreFeatures(bpm: 130, energy: 0.70, valence: 0.50, instrumentalness: 0.15),
            "punk": GenreFeatures(bpm: 160, energy: 0.80, valence: 0.45, instrumentalness: 0.10),
            "metal": GenreFeatures(bpm: 140, energy: 0.85, valence: 0.30, instrumentalness: 0.20),
            "electronic": GenreFeatures(bpm: 128, energy: 0.65, valence: 0.55, instrumentalness: 0.60),
            "dance": GenreFeatures(bpm: 128, energy: 0.75, valence: 0.70, instrumentalness: 0.40),
            "house": GenreFeatures(bpm: 126, energy: 0.70, valence: 0.60, instrumentalness: 0.55),
            "techno": GenreFeatures(bpm: 130, energy: 0.75, valence: 0.40, instrumentalness: 0.75),
            "hip-hop": GenreFeatures(bpm: 90, energy: 0.50, valence: 0.45, instrumentalness: 0.05),
            "rap": GenreFeatures(bpm: 85, energy: 0.55, valence: 0.40, instrumentalness: 0.05),
            "trap": GenreFeatures(bpm: 140, energy: 0.60, valence: 0.35, instrumentalness: 0.10),
            "reggae": GenreFeatures(bpm: 80, energy: 0.40, valence: 0.65, instrumentalness: 0.15),
            "latin": GenreFeatures(bpm: 100, energy: 0.60, valence: 0.75, instrumentalness: 0.10),
            "k-pop": GenreFeatures(bpm: 125, energy: 0.70, valence: 0.75, instrumentalness: 0.05),
            "lofi": GenreFeatures(bpm: 75, energy: 0.20, valence: 0.45, instrumentalness: 0.60),
        ]

        // Try exact match
        if let features = table[normalized] {
            return features
        }

        // Try partial match
        for (key, features) in table {
            if normalized.contains(key) || key.contains(normalized) {
                return features
            }
        }

        // Default: moderate everything
        return GenreFeatures(bpm: 110, energy: 0.50, valence: 0.50, instrumentalness: 0.30)
    }
}

#endif
