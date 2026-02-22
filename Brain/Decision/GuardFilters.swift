//
//  GuardFilters.swift
//  Resonance
//
//  Pre-scoring filters that remove candidates that should never be selected.
//  Applied before the SongScorer to reduce the candidate pool and enforce
//  hard constraints like recency, same-artist limits, and time-of-day BPM caps.
//

#if os(iOS)

import Foundation
import CoreData

// MARK: - Filter Result

/// Describes why a song was filtered out.
enum FilterReason: String {
    case playedRecently = "Played too recently"
    case sameArtistLimit = "Too many songs from same artist in a row"
    case bpmTooHighForTime = "BPM too high for current time of day"
    case bpmTooHighForState = "BPM too high for current biometric state"
    case energyMismatch = "Energy level mismatched for guard adjustment"
    case noValidId = "Song has no valid identifier"
}

/// Result of applying guard filters to a candidate list.
struct FilterResult {
    /// Songs that passed all filters.
    let accepted: [Song]

    /// Songs that were filtered out, with reasons.
    let rejected: [(song: Song, reason: FilterReason)]

    /// Number of candidates before filtering.
    let totalCandidates: Int

    /// Number of candidates after filtering.
    var acceptedCount: Int { accepted.count }
}

// MARK: - Guard Filters

/// Applies hard filters to the candidate pool before scoring.
/// These are non-negotiable constraints that override any score.
final class GuardFilters {

    // MARK: - Main Entry Point

    /// Applies all guard filters to the candidate song list.
    /// Returns only songs that pass every filter.
    ///
    /// - Parameters:
    ///   - candidates: All songs in the playlist.
    ///   - context: The current decision context.
    ///   - recentArtists: Trailing list of artist names from the current session (most recent last).
    func apply(
        candidates: [Song],
        context: DecisionContext,
        recentArtists: [String] = []
    ) -> FilterResult {
        var accepted: [Song] = []
        var rejected: [(song: Song, reason: FilterReason)] = []

        for song in candidates {
            // Filter 1: Must have a valid ID
            guard song.id != nil else {
                rejected.append((song, .noValidId))
                continue
            }

            // Filter 2: Recency — skip songs played too recently
            if let songId = song.id, context.wasPlayedRecently(songId) {
                rejected.append((song, .playedRecently))
                continue
            }

            // Filter 3: Same-artist limit
            if let artistName = song.artistName,
               shouldFilterByArtist(
                   artistName: artistName,
                   recentArtists: recentArtists,
                   maxInRow: context.preferences.maxSameArtistInRow
               ) {
                rejected.append((song, .sameArtistLimit))
                continue
            }

            // Filter 4: Time-of-day BPM cap (hard cap, not just a penalty)
            if shouldFilterByTimeBPM(song: song, context: context) {
                rejected.append((song, .bpmTooHighForTime))
                continue
            }

            accepted.append(song)
        }

        logDebug(
            "GuardFilters: \(accepted.count)/\(candidates.count) candidates accepted, "
            + "\(rejected.count) filtered",
            category: .decisionEngine
        )

        return FilterResult(
            accepted: accepted,
            rejected: rejected,
            totalCandidates: candidates.count
        )
    }

    // MARK: - Guard Adjustment Filtering

    /// Apply guard adjustment filters on top of standard filters.
    /// Called when RealTimeGuardAdjuster has active adjustments.
    func applyWithGuardAdjustments(
        candidates: [Song],
        context: DecisionContext,
        recentArtists: [String] = [],
        bpmAdjustment: Double = 0.0
    ) -> FilterResult {
        // First apply standard filters
        var result = apply(candidates: candidates, context: context, recentArtists: recentArtists)

        // If no BPM adjustment, return standard result
        guard bpmAdjustment < -5.0 else { return result }

        // Additional filtering: if guard says lower BPM, filter songs above adjusted cap
        let currentNeed = context.stateVector.inferredNeed
        guard currentNeed == .calm || currentNeed == .focus else { return result }

        let adjustedMaxBPM = (context.preferences.nightMaxBPM + 30) + bpmAdjustment

        var stillAccepted: [Song] = []
        var newRejected = result.rejected

        for song in result.accepted {
            if song.bpm > adjustedMaxBPM && song.bpm > 0 {
                newRejected.append((song: song, reason: .bpmTooHighForState))
            } else {
                stillAccepted.append(song)
            }
        }

        // Only apply if we still have enough candidates (don't filter to empty)
        if stillAccepted.count >= 3 {
            return FilterResult(
                accepted: stillAccepted,
                rejected: newRejected,
                totalCandidates: result.totalCandidates
            )
        }

        return result  // Fall back to unmodified result if too aggressive
    }

    // MARK: - Same-Artist Filter

    /// Determines if a song should be filtered because too many songs from the
    /// same artist have been played in a row.
    private func shouldFilterByArtist(
        artistName: String,
        recentArtists: [String],
        maxInRow: Int
    ) -> Bool {
        guard !recentArtists.isEmpty else { return false }

        // Count how many of the last N songs are by the same artist
        let trailing = recentArtists.suffix(maxInRow)
        let sameArtistCount = trailing.filter { $0.lowercased() == artistName.lowercased() }.count

        return sameArtistCount >= maxInRow
    }

    // MARK: - Time-of-Day BPM Filter

    /// Hard-filters songs with BPM significantly over the time-of-day maximum.
    /// Only applies at night (preSleep context or nighttime) with a generous buffer.
    private func shouldFilterByTimeBPM(song: Song, context: DecisionContext) -> Bool {
        let songBPM = song.bpm
        guard songBPM > 0 else { return false } // Unknown BPM → don't filter

        // Only hard-filter during nighttime or preSleep context
        let isNightContext = context.stateVector.context == .preSleep || context.isNighttime

        guard isNightContext else { return false }

        // Hard cap with generous buffer (30 BPM above the nightMaxBPM)
        let hardCap = context.preferences.nightMaxBPM + 30
        return songBPM > hardCap
    }
}

#endif
