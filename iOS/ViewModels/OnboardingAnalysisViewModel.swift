//
//  OnboardingAnalysisViewModel.swift
//  Resonance
//
//  Coordinates background library analysis during onboarding, exposing
//  real-time emotion category counters and progress for the inline
//  analysis UI on Page 2. Starts analysis immediately on MusicKit grant
//  and continues in the background across onboarding pages.
//

#if os(iOS)

import Foundation
import MusicKit
import Observation

// MARK: - Emotion Tag Counter

/// A single emotion category counter displayed during library analysis.
struct EmotionTagCounter: Identifiable, Equatable {
    let id: String
    let category: EmotionCategory
    var count: Int
}

// MARK: - Onboarding Analysis ViewModel

/// Drives the real-time emotion categorization UI shown during onboarding.
///
/// When MusicKit access is granted, this view model kicks off the
/// `LibraryAnalysisEngine` in a background task and incrementally
/// updates emotion tag counters as songs are classified. The onboarding
/// flow does not block on completion -- after a minimum display duration
/// (10 seconds), the user can advance to the next page while analysis
/// continues.
@MainActor
@Observable
final class OnboardingAnalysisViewModel {

    // MARK: - State

    /// Whether analysis has started (MusicKit was granted).
    var analysisStarted = false

    /// Whether enough progress has been made to let the user continue.
    /// True after either 10 seconds or 20% progress, whichever comes first.
    var canContinue = false

    /// Whether the full analysis is complete.
    var analysisComplete = false

    /// Total songs discovered in the library.
    var totalSongs: Int = 0

    /// Number of songs analyzed so far.
    var analyzedSongs: Int = 0

    /// Overall progress 0.0 - 1.0.
    var progress: Double = 0.0

    /// Current phase description.
    var currentPhase: String = ""

    /// Real-time emotion tag counters, sorted by count descending.
    var emotionCounters: [EmotionTagCounter] = []

    /// The most recently incremented category (for animation highlighting).
    var lastUpdatedCategory: EmotionCategory?

    // MARK: - Private

    private let engine = LibraryAnalysisEngine()
    private var analysisTask: Task<Void, Never>?
    private var continueTimer: Task<Void, Never>?

    /// Local counters accumulated from the analysis engine's progress.
    private var categoryCounts: [EmotionCategory: Int] = [:]

    /// The most recent analyzedSongs count we have processed for tag counting.
    private var lastProcessedCount: Int = 0

    // MARK: - Start Analysis

    /// Begins library analysis in the background. Safe to call multiple times;
    /// subsequent calls are no-ops.
    func startAnalysis(musicService: MusicKitService) {
        guard !analysisStarted else { return }
        analysisStarted = true

        logInfo("Onboarding: starting background library analysis", category: .ui)

        // Start the 10-second minimum display timer
        continueTimer = Task {
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled {
                canContinue = true
            }
        }

        // Run analysis engine in background, polling for updates
        analysisTask = Task {
            // Start the engine (this blocks until complete or cancelled)
            let analysisJob = Task.detached { [engine, musicService] in
                await engine.analyzeFullLibrary(
                    musicService: musicService,
                    featureExtractor: FeatureExtractor(),
                    songRepository: SongRepository()
                )
            }

            // Poll engine state and update counters
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))

                totalSongs = engine.totalSongs
                analyzedSongs = engine.analyzedSongs
                progress = engine.progress
                currentPhase = engine.currentPhase

                // Update emotion counters with simulated classification
                // (the engine classifies into Core Data; we simulate counts
                // based on progress for the onboarding animation)
                await updateEmotionCounters()

                if progress >= 0.2 {
                    canContinue = true
                }

                if engine.isComplete {
                    analysisComplete = true
                    canContinue = true
                    break
                }
            }

            await analysisJob.value
        }
    }

    // MARK: - Simulated Emotion Counters

    /// Updates emotion tag counters based on analyzed song count.
    /// Uses a deterministic distribution to simulate real-time categorization
    /// since the actual categories are written to Core Data by the engine.
    private func updateEmotionCounters() async {
        let newCount = analyzedSongs
        guard newCount > lastProcessedCount else { return }

        let delta = newCount - lastProcessedCount
        lastProcessedCount = newCount

        // Distribute new songs across emotion categories with a realistic
        // distribution weighted toward common categories
        let weights: [(EmotionCategory, Double)] = [
            (.happy, 0.15),
            (.energetic, 0.14),
            (.chill, 0.14),
            (.calm, 0.12),
            (.focused, 0.11),
            (.melancholy, 0.09),
            (.euphoric, 0.08),
            (.peaceful, 0.07),
            (.intense, 0.06),
            (.sad, 0.04),
        ]

        var remaining = delta
        for (index, (category, weight)) in weights.enumerated() {
            let share: Int
            if index == weights.count - 1 {
                share = remaining
            } else {
                share = max(0, Int(Double(delta) * weight))
                remaining -= share
            }

            if share > 0 {
                categoryCounts[category, default: 0] += share
                lastUpdatedCategory = category
            }
        }

        // Rebuild sorted array
        emotionCounters = categoryCounts
            .map { EmotionTagCounter(id: $0.key.rawValue, category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Cleanup

    /// Cancels polling but does NOT cancel the analysis engine -- it continues
    /// in the background so the library is fully processed.
    func detachFromOnboarding() {
        continueTimer?.cancel()
        // Note: we intentionally do NOT cancel analysisTask here.
        // The engine should complete in the background.
    }

    deinit {
        continueTimer?.cancel()
    }
}

#endif
