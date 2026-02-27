//
//  TransitionController.swift
//  Resonance
//
//  Controls smooth transitions between songs by adjusting scores
//  based on how well a candidate follows the previously played song.
//  Implements plan.md §5.2.3 (selectWithTransition, calculateTransitionScore).
//

#if os(iOS)

import Foundation
import CoreData

// MARK: - Transition Score

/// Details of how well a song transitions from the previous song.
struct TransitionScore: Sendable {
    /// BPM transition smoothness (0.0 = large jump, 1.0 = smooth)
    let bpmSmoothness: Double

    /// Energy transition smoothness (0.0 = large jump, 1.0 = smooth)
    let energySmoothness: Double

    /// Bonus for shared genre
    let genreBonus: Double

    /// Combined transition score (0.0 - 1.0)
    let combined: Double
}

// MARK: - Transition Controller

/// Adjusts song scores to ensure smooth transitions between consecutive songs.
/// When smooth transitions are enabled, candidates are re-ranked to prefer songs
/// that flow naturally from the last played song.
final class TransitionController {

    // MARK: - Main Entry Point (plan.md §5.2.3)

    /// Selects the best song considering transition smoothness.
    /// If this is the first song of a session or transitions are disabled,
    /// simply returns the highest-scored candidate.
    func selectWithTransition(
        candidates: [SongScore],
        lastPlayedSong: Song?,
        enableSmoothTransitions: Bool,
        context: NSManagedObjectContext
    ) -> SongScore? {
        guard !candidates.isEmpty else { return nil }

        // First song of session or transitions disabled — pick highest score
        guard let lastSong = lastPlayedSong, enableSmoothTransitions else {
            return candidates.first // Already sorted by finalScore descending
        }

        // Precompute genre categories for the last-played song (avoids recomputing per candidate)
        let fromGenreCategories: Set<String> = {
            guard let genres = lastSong.genreNames, !genres.isEmpty else { return [] }
            return categorize(genres: genres)
        }()

        // Batch-fetch all candidate songs in a single Core Data query
        let candidateIds = candidates.map { $0.songId }
        let songLookup = fetchSongs(songIds: candidateIds, in: context)

        // Adjust scores with transition bonus
        let adjustedCandidates = candidates.map { candidate -> (score: SongScore, adjustedScore: Double) in
            let song = songLookup[candidate.songId]

            let adjustedScore: Double
            if song != nil {
                let transitionScore = calculateTransitionScore(
                    from: lastSong,
                    to: song,
                    fromGenreCategories: fromGenreCategories
                )
                // Blend: 70% base score + 30% transition quality
                adjustedScore = candidate.finalScore * (0.7 + transitionScore.combined * 0.3)
            } else {
                // Cannot resolve song — use base score without transition bonus
                adjustedScore = candidate.finalScore * 0.7
            }

            return (candidate, adjustedScore)
        }

        // Return the candidate with the highest adjusted score
        return adjustedCandidates.max(by: { $0.adjustedScore < $1.adjustedScore })?.score
    }

    // MARK: - Transition Score Calculation (plan.md §5.2.3)

    /// Calculates how smoothly a transition from one song to another would be.
    func calculateTransitionScore(
        from: Song,
        to: Song?,
        fromGenreCategories: Set<String>? = nil
    ) -> TransitionScore {
        guard let to = to else {
            return TransitionScore(bpmSmoothness: 1.0, energySmoothness: 1.0, genreBonus: 0.0, combined: 1.0)
        }

        // BPM transition smoothness
        let bpmSmoothness: Double
        let fromBPM = from.bpm
        let toBPM = to.bpm
        if fromBPM > 0 && toBPM > 0 {
            let bpmDelta = abs(fromBPM - toBPM)
            bpmSmoothness = max(0.0, 1.0 - (bpmDelta / DecisionEngineConstants.maxBPMTransitionDelta))
        } else {
            bpmSmoothness = 0.5 // Unknown BPM → neutral
        }

        // Energy transition smoothness
        let energyDelta = abs(from.energyEstimate - to.energyEstimate)
        let energySmoothness = max(0.0, 1.0 - (energyDelta / DecisionEngineConstants.maxEnergyTransitionDelta))

        // Genre compatibility bonus
        let genreBonus: Double
        if let precomputed = fromGenreCategories {
            genreBonus = sharesGenre(fromCategories: precomputed, to) ? 0.1 : 0.0
        } else {
            genreBonus = sharesGenre(from, to) ? 0.1 : 0.0
        }

        // Combined score (plan.md §5.2.3)
        let combined = (bpmSmoothness * 0.4) + (energySmoothness * 0.4) + genreBonus

        return TransitionScore(
            bpmSmoothness: bpmSmoothness,
            energySmoothness: energySmoothness,
            genreBonus: genreBonus,
            combined: combined
        )
    }

    // MARK: - Genre Comparison

    /// Checks if two songs share at least one genre category.
    private func sharesGenre(_ a: Song, _ b: Song) -> Bool {
        guard let genresA = a.genreNames,
              let genresB = b.genreNames,
              !genresA.isEmpty, !genresB.isEmpty else {
            return false
        }

        let categoryA = categorize(genres: genresA)
        let categoryB = categorize(genres: genresB)

        return !categoryA.isDisjoint(with: categoryB)
    }

    /// Checks if precomputed `from` categories overlap with a song's genre categories.
    private func sharesGenre(fromCategories: Set<String>, _ b: Song) -> Bool {
        guard !fromCategories.isEmpty,
              let genresB = b.genreNames, !genresB.isEmpty else {
            return false
        }
        let categoryB = categorize(genres: genresB)
        return !fromCategories.isDisjoint(with: categoryB)
    }

    /// Maps genre names to broad categories using SongFeatures.genreCategories.
    private func categorize(genres: [String]) -> Set<String> {
        var categories = Set<String>()
        for genre in genres {
            let lowercased = genre.lowercased()
            for (category, keywords) in SongFeatures.genreCategories {
                if keywords.contains(where: { lowercased.contains($0) }) {
                    categories.insert(category)
                }
            }
        }
        return categories
    }

    // MARK: - Helpers

    /// Fetches multiple Songs by their UUIDs in a single Core Data query.
    /// Returns a dictionary keyed by song ID for O(1) lookup.
    private func fetchSongs(songIds: [UUID], in context: NSManagedObjectContext) -> [UUID: Song] {
        guard !songIds.isEmpty else { return [:] }
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "id IN %@", songIds)
        guard let results = try? context.fetch(request) else { return [:] }
        return Dictionary(results.compactMap { song -> (UUID, Song)? in
            guard let id = song.id else { return nil }
            return (id, song)
        }, uniquingKeysWith: { first, _ in first })
    }

    /// Fetches a Song by its UUID.
    private func fetchSong(songId: UUID, in context: NSManagedObjectContext) -> Song? {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "id == %@", songId as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

#endif
