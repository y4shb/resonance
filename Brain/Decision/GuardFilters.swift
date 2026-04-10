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
    case vocalsInFocusMode = "Vocal track filtered in focus mode"
    case unsafeForDriving = "Song too intense or distracting for driving"
    case anxiolyticOverride = "Song filtered by anxiolytic profile (BPM/key/familiarity)"
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
    ///   - isDriving: Whether the user is currently driving (Workstream 3.5).
    ///   - anxietyLevel: Current detected anxiety level for anxiolytic filtering.
    func apply(
        candidates: [Song],
        context: DecisionContext,
        recentArtists: [String] = [],
        isDriving: Bool = false,
        anxietyLevel: AnxietyLevel = .calm
    ) -> FilterResult {
        var accepted: [Song] = []
        var rejected: [(song: Song, reason: FilterReason)] = []

        for song in candidates {
            // Filter 1: Must have a valid ID
            guard let songId = song.id else {
                rejected.append((song, .noValidId))
                continue
            }

            // Filter 2: Recency — skip songs played too recently
            if context.wasPlayedRecently(songId) {
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

            // Filter 5: Vocal tracks in focus mode
            if shouldFilterVocalsForFocus(song: song, context: context) {
                rejected.append((song, .vocalsInFocusMode))
                continue
            }

            // Filter 6: Driving safety filter (Workstream 3.5)
            if isDriving && shouldFilterForDriving(song: song) {
                rejected.append((song, .unsafeForDriving))
                continue
            }

            accepted.append(song)
        }

        // Filter 7: Anxiolytic profile filter
        // Applied after standard filters to ensure we can guarantee minimum track count.
        // Gradual: .elevated = soft preference, .anxious = hard filter, .acute = strictest
        if anxietyLevel.severity >= AnxietyLevel.elevated.severity {
            let anxiolyticResult = applyAnxiolyticFilter(
                accepted: accepted,
                anxietyLevel: anxietyLevel
            )
            accepted = anxiolyticResult.accepted
            rejected.append(contentsOf: anxiolyticResult.rejected)
        }

        logDebug(
            "GuardFilters: \(accepted.count)/\(candidates.count) candidates accepted, "
            + "\(rejected.count) filtered"
            + (anxietyLevel != .calm ? " (anxiety: \(anxietyLevel.rawValue))" : ""),
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
        let result = apply(candidates: candidates, context: context, recentArtists: recentArtists)

        // If no BPM adjustment, return standard result
        guard bpmAdjustment < -5.0 else { return result }

        // Additional filtering: if guard says lower BPM, filter songs above adjusted cap
        let currentNeed = context.stateVector.inferredNeed
        guard currentNeed == .calm || currentNeed == .focus else { return result }

        let adjustedMaxBPM = (context.preferences.nightMaxBPM + 30) + bpmAdjustment

        var stillAccepted: [Song] = []
        var newRejected = result.rejected

        for song in result.accepted {
            if song.bpm > 0 && song.bpm > adjustedMaxBPM {
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
        let lowercasedArtist = artistName.lowercased()
        let sameArtistCount = trailing.filter { $0.lowercased() == lowercasedArtist }.count

        return sameArtistCount >= maxInRow
    }

    // MARK: - Focus-Mode Vocal Filter

    /// Filters vocal tracks during focus contexts (deepWork, work).
    /// Only applies as a hard filter for deepWork; work mode uses soft scoring
    /// penalty instead (handled by SongScorer).
    private func shouldFilterVocalsForFocus(song: Song, context: DecisionContext) -> Bool {
        // Only hard-filter in deep work context
        guard context.stateVector.context == .deepWork else { return false }

        // Only filter if instrumentalness is low (i.e. has vocals)
        return song.instrumentalness < 0.3
    }

    // MARK: - Driving Safety Filter (Workstream 3.5)

    /// Filters songs that are too intense for safe driving.
    /// Removes tracks with very high BPM or very high energy that could
    /// be overly distracting or induce aggressive driving behavior.
    private func shouldFilterForDriving(song: Song) -> Bool {
        let songBPM = song.bpm

        // Hard-filter extremely fast tracks while driving
        if songBPM > 0 && songBPM > 160 {
            return true
        }

        // Filter very high energy + high BPM combinations
        if songBPM > 140 && song.energyEstimate > 0.85 {
            return true
        }

        return false
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

    // MARK: - Anxiolytic Profile Filter

    /// Filters candidates based on anxiety level to promote calming music.
    ///
    /// Gradual filtering:
    /// - `.elevated`: Soft preference — rank songs but don't hard-reject.
    ///   BPM cap at 100, instrumentalness threshold 0.3 (lenient).
    /// - `.anxious`: Hard filter — BPM 60-80, prefer major keys, high familiarity,
    ///   instrumentalness > 0.5.
    /// - `.acute`: Strictest — BPM 60-75, instrumentalness > 0.6, familiarity > 0.4.
    ///
    /// Safety net: Always allows at least the top 3 most familiar tracks through,
    /// even if they fail the anxiolytic criteria.
    private func applyAnxiolyticFilter(
        accepted: [Song],
        anxietyLevel: AnxietyLevel
    ) -> (accepted: [Song], rejected: [(song: Song, reason: FilterReason)]) {
        guard anxietyLevel.severity >= AnxietyLevel.elevated.severity else {
            return (accepted: accepted, rejected: [])
        }

        // Determine thresholds based on anxiety severity
        let bpmCap: Double
        let instrumentalnessThreshold: Double
        let familiarityThreshold: Double

        switch anxietyLevel {
        case .elevated:
            // Soft preference: generous BPM cap, minimal instrumentalness requirement
            bpmCap = 100.0
            instrumentalnessThreshold = 0.3
            familiarityThreshold = 0.0
        case .anxious:
            // Hard filter: restrict to calming range
            bpmCap = 80.0
            instrumentalnessThreshold = 0.5
            familiarityThreshold = 0.2
        case .acute:
            // Strictest: maximum calming constraints
            bpmCap = 75.0
            instrumentalnessThreshold = 0.6
            familiarityThreshold = 0.4
        case .calm:
            return (accepted: accepted, rejected: [])
        }

        var passed: [Song] = []
        var failed: [(song: Song, reason: FilterReason)] = []

        for song in accepted {
            let songBPM = song.bpm
            let songInstrumentalness = song.instrumentalness

            // BPM check (skip if BPM unknown)
            let bpmOK = songBPM <= 0 || songBPM <= bpmCap

            // Instrumentalness check
            let instrumentalOK = songInstrumentalness >= instrumentalnessThreshold

            // Familiarity check
            let familiarityOK = song.familiarityScore >= familiarityThreshold

            // For elevated level, only filter if BOTH BPM and instrumentalness fail
            if anxietyLevel == .elevated {
                if bpmOK || instrumentalOK {
                    passed.append(song)
                } else {
                    failed.append((song: song, reason: .anxiolyticOverride))
                }
            } else {
                // For anxious/acute, require BPM compliance AND at least one of
                // instrumentalness or familiarity
                if bpmOK && (instrumentalOK || familiarityOK) {
                    passed.append(song)
                } else {
                    failed.append((song: song, reason: .anxiolyticOverride))
                }
            }
        }

        // Safety net: always allow at least the top 3 most familiar tracks through.
        // This prevents the filter from being too aggressive and leaving no candidates.
        let minimumPassthrough = 3
        if passed.count < minimumPassthrough {
            // Sort failed songs by familiarity (highest first) and rescue the top ones
            let sortedFailed = failed.sorted { $0.song.familiarityScore > $1.song.familiarityScore }
            let rescueCount = min(minimumPassthrough - passed.count, sortedFailed.count)

            for i in 0..<rescueCount {
                passed.append(sortedFailed[i].song)
            }

            // Remove rescued songs from the failed list
            let rescuedIds = Set(sortedFailed.prefix(rescueCount).compactMap { $0.song.id })
            failed.removeAll { rescuedIds.contains($0.song.id ?? UUID()) }

            if rescueCount > 0 {
                logDebug(
                    "Anxiolytic filter: rescued \(rescueCount) familiar tracks "
                    + "(safety net, \(anxietyLevel.rawValue) level)",
                    category: .decisionEngine
                )
            }
        }

        return (accepted: passed, rejected: failed)
    }
}

#endif
