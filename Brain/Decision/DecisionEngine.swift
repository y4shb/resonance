//
//  DecisionEngine.swift
//  Resonance
//
//  The DJ Brain orchestrator. Combines guard filters, song scoring,
//  transition control, and explanation generation into a single pipeline
//  that selects the next song to play.
//

#if os(iOS)

import Foundation
import CoreData

// MARK: - Decision Result

/// The output of the decision engine — a selected song with explanation.
struct DecisionResult {
    /// The selected song's UUID (Core Data id attribute).
    let songId: UUID

    /// The full SongScore breakdown (includes title, artist, explanation components).
    let score: SongScore

    /// Human-readable explanation of why this song was chosen.
    let explanation: SongExplanation

    /// How many candidates were considered.
    let candidatesConsidered: Int

    /// How many candidates were filtered out.
    let candidatesFiltered: Int
}

// MARK: - Decision Engine

/// The AI DJ brain. Given the current user state and an active playlist,
/// selects the optimal next song to play.
@MainActor
final class DecisionEngine: ObservableObject {

    // MARK: - Published State

    /// The most recent decision result, for UI display.
    @Published private(set) var lastDecision: DecisionResult?

    /// Whether a decision is currently being computed.
    @Published private(set) var isDeciding: Bool = false

    // MARK: - Dependencies

    private let persistence: PersistenceController
    private let songScorer: SongScorer
    private let guardFilters: GuardFilters
    private let transitionController: TransitionController
    private let explanationGenerator: ExplanationGenerator

    /// Real-time guard adjuster for biometric-aware filtering
    var guardAdjuster: RealTimeGuardAdjuster?

    // MARK: - Session Tracking

    /// Songs played in the current session (ordered, most recent last).
    private var sessionSongIds: [UUID] = []

    /// Artist names played in the current session (ordered, most recent last).
    private var sessionArtists: [String] = []

    /// Recently played songs with timestamps for recency filtering.
    private var recentlyPlayed: [UUID: Date] = [:]

    /// The last played song's UUID (for transition logic).
    private var lastPlayedSongId: UUID?

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        self.songScorer = SongScorer()
        self.guardFilters = GuardFilters()
        self.transitionController = TransitionController()
        self.explanationGenerator = ExplanationGenerator()

        logInfo("DecisionEngine initialized", category: .decisionEngine)
    }

    // MARK: - Main Decision Pipeline

    /// Selects the next song to play from the active playlist.
    ///
    /// Pipeline:
    /// 1. Fetch candidate songs from the playlist
    /// 2. Apply guard filters (recency, artist limits, time-of-day)
    /// 3. Score all remaining candidates
    /// 4. Apply transition logic
    /// 5. Generate explanation
    /// 6. Return the selected song
    func selectNextSong(
        playlistId: UUID,
        playlistName: String,
        stateVector: StateVector,
        preferences: UserPreferences = .load()
    ) async -> DecisionResult? {
        guard !isDeciding else {
            logWarning("DecisionEngine: selectNextSong called while already deciding", category: .decisionEngine)
            return lastDecision
        }

        isDeciding = true
        defer { isDeciding = false }

        logInfo(
            "DecisionEngine: selecting next song for playlist '\(playlistName)' "
            + "(need: \(stateVector.inferredNeed.rawValue), context: \(stateVector.context.rawValue))",
            category: .decisionEngine
        )

        let context = persistence.viewContext

        // 1. Fetch candidate songs from the playlist
        let candidates = fetchCandidateSongs(playlistId: playlistId, in: context)

        guard !candidates.isEmpty else {
            logWarning("DecisionEngine: no candidate songs found in playlist '\(playlistName)'", category: .decisionEngine)
            return nil
        }

        logDebug("DecisionEngine: \(candidates.count) candidate songs loaded", category: .decisionEngine)

        // Build the decision context
        let candidateIds = candidates.compactMap { $0.id }
        let decisionContext = DecisionContext(
            stateVector: stateVector,
            activePlaylistId: playlistId,
            activePlaylistName: playlistName,
            candidateSongIds: candidateIds,
            recentlyPlayed: recentlyPlayed,
            currentTime: Date(),
            currentSessionSongIds: sessionSongIds,
            preferences: preferences,
            isSessionStart: sessionSongIds.isEmpty
        )

        // 2. Apply guard filters
        let filterResult: FilterResult
        if let adjuster = guardAdjuster, adjuster.hasActiveAdjustments {
            filterResult = guardFilters.applyWithGuardAdjustments(
                candidates: candidates,
                context: decisionContext,
                recentArtists: sessionArtists,
                bpmAdjustment: adjuster.bpmAdjustment
            )
            logInfo("Guard adjustments active: BPM adj=\(String(format: "%.0f", adjuster.bpmAdjustment)), "
                    + "familiarity boost=\(String(format: "%.2f", adjuster.familiarityBoost))",
                    category: .decisionEngine)
        } else {
            filterResult = guardFilters.apply(
                candidates: candidates,
                context: decisionContext,
                recentArtists: sessionArtists
            )
        }

        guard !filterResult.accepted.isEmpty else {
            logWarning(
                "DecisionEngine: all \(candidates.count) candidates were filtered out — "
                + "falling back to highest-scored unfiltered",
                category: .decisionEngine
            )
            // Fallback: score all candidates without filtering
            return selectFallback(
                candidates: candidates,
                context: decisionContext,
                in: context
            )
        }

        // 3. Score all remaining candidates
        var scores = songScorer.scoreAllCandidates(
            filterResult.accepted,
            context: decisionContext
        )

        // Apply familiarity boost from guard adjuster (if active)
        if let adjuster = guardAdjuster, adjuster.hasActiveAdjustments {
            let boost = adjuster.familiarityBoost
            if boost > 0 {
                scores = scores.map { score in
                    let adjustedFinalScore = score.finalScore + score.familiarityScore * boost
                    return SongScore(
                        songId: score.songId,
                        songTitle: score.songTitle,
                        artistName: score.artistName,
                        albumName: score.albumName,
                        bpm: score.bpm,
                        bpmMatchScore: score.bpmMatchScore,
                        energyMatchScore: score.energyMatchScore,
                        familiarityScore: score.familiarityScore,
                        historicalEffectScore: score.historicalEffectScore,
                        contextAlignmentScore: score.contextAlignmentScore,
                        recencyPenalty: score.recencyPenalty,
                        timeOfDayScore: score.timeOfDayScore,
                        finalScore: adjustedFinalScore,
                        confidence: score.confidence,
                        explanationComponents: score.explanationComponents
                    )
                }.sorted { $0.finalScore > $1.finalScore }
            }
        }

        let lastPlayedSong = fetchLastPlayedSong(in: context)

        guard !scores.isEmpty else {
            logWarning("DecisionEngine: scoring produced no results", category: .decisionEngine)
            return nil
        }

        // 4. Apply transition logic
        let selectedScore: SongScore
        if let transitioned = transitionController.selectWithTransition(
            candidates: scores,
            lastPlayedSong: lastPlayedSong,
            enableSmoothTransitions: preferences.enableSmoothTransitions,
            context: context
        ) {
            selectedScore = transitioned
        } else {
            selectedScore = scores[0]
        }

        // 5. Generate explanation
        let explanation = explanationGenerator.generate(
            score: selectedScore,
            state: stateVector,
            isSessionStart: decisionContext.isSessionStart
        )

        // 6. Build result
        let result = DecisionResult(
            songId: selectedScore.songId,
            score: selectedScore,
            explanation: explanation,
            candidatesConsidered: filterResult.totalCandidates,
            candidatesFiltered: filterResult.rejected.count
        )

        // Update session tracking
        recordSelection(songId: selectedScore.songId, artistName: selectedScore.artistName)

        lastDecision = result

        logInfo(
            "DecisionEngine: selected '\(selectedScore.songTitle)' by \(selectedScore.artistName) "
            + "(score: \(String(format: "%.3f", selectedScore.finalScore)), "
            + "confidence: \(String(format: "%.2f", selectedScore.confidence)))",
            category: .decisionEngine
        )

        return result
    }

    // MARK: - Session Management

    /// Resets the session tracking (e.g., when a new playlist is selected).
    func resetSession() {
        sessionSongIds.removeAll()
        sessionArtists.removeAll()
        recentlyPlayed.removeAll()
        lastPlayedSongId = nil
        lastDecision = nil
        logInfo("DecisionEngine: session reset", category: .decisionEngine)
    }

    // MARK: - Private Helpers

    /// Fetches all songs in the given playlist.
    private func fetchCandidateSongs(playlistId: UUID, in context: NSManagedObjectContext) -> [Song] {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "ANY playlists.id == %@", playlistId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        request.fetchBatchSize = 50

        do {
            return try context.fetch(request)
        } catch {
            logError("DecisionEngine: failed to fetch candidate songs", error: error, category: .decisionEngine)
            return []
        }
    }

    /// Fetches the last played Song object by its UUID.
    private func fetchLastPlayedSong(in context: NSManagedObjectContext) -> Song? {
        guard let songId = lastPlayedSongId else { return nil }
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "id == %@", songId as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// Records a song selection in session tracking.
    private func recordSelection(songId: UUID, artistName: String) {
        lastPlayedSongId = songId
        sessionSongIds.append(songId)
        recentlyPlayed[songId] = Date()
        sessionArtists.append(artistName)
        trimSessionData()
    }

    /// Prevents session tracking arrays from growing unbounded in long sessions.
    private func trimSessionData() {
        let maxEntries = 500
        if sessionSongIds.count > maxEntries {
            sessionSongIds = Array(sessionSongIds.suffix(maxEntries))
        }
        if sessionArtists.count > maxEntries {
            sessionArtists = Array(sessionArtists.suffix(maxEntries))
        }
        // Prune recentlyPlayed entries older than 16 hours
        let cutoff = Date().addingTimeInterval(-960.0 * 60.0)
        recentlyPlayed = recentlyPlayed.filter { $0.value > cutoff }
    }

    /// Fallback selection when all candidates are filtered.
    /// Scores unfiltered candidates but with extra recency penalty suppressed.
    private func selectFallback(
        candidates: [Song],
        context: DecisionContext,
        in managedContext: NSManagedObjectContext
    ) -> DecisionResult? {
        // Create a context with no recency data so nothing gets penalized
        let fallbackContext = DecisionContext(
            stateVector: context.stateVector,
            activePlaylistId: context.activePlaylistId,
            activePlaylistName: context.activePlaylistName,
            candidateSongIds: context.candidateSongIds,
            recentlyPlayed: [:],
            currentTime: context.currentTime,
            currentSessionSongIds: [],
            preferences: context.preferences,
            isSessionStart: true
        )

        let scores = songScorer.scoreAllCandidates(
            candidates,
            context: fallbackContext
        )

        guard let best = scores.first else { return nil }

        let explanation = explanationGenerator.generate(
            score: best,
            state: context.stateVector,
            isSessionStart: true
        )

        let result = DecisionResult(
            songId: best.songId,
            score: best,
            explanation: explanation,
            candidatesConsidered: candidates.count,
            candidatesFiltered: 0
        )

        recordSelection(songId: best.songId, artistName: best.artistName)
        lastDecision = result

        logInfo(
            "DecisionEngine (fallback): selected '\(best.songTitle)' "
            + "(score: \(String(format: "%.3f", best.finalScore)))",
            category: .decisionEngine
        )

        return result
    }
}

#endif
