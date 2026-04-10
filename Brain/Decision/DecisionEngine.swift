//
//  DecisionEngine.swift
//  Resonance
//
//  The DJ Brain orchestrator. Combines guard filters, song scoring,
//  transition control, explanation generation, and session arc planning
//  (WS-4) into a single pipeline that selects the next song to play.
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

    /// Biometric-adaptive crossfade parameters for the transition into this song.
    let crossfadeParameters: CrossfadeParameters
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
    @Published private(set) var isDeciding = false

    // MARK: - Dependencies

    private let persistence: PersistenceController
    private let songScorer: SongScorer
    private let guardFilters: GuardFilters
    private let transitionController: TransitionController
    private let explanationGenerator: ExplanationGenerator
    private let effectivenessLearner: EffectivenessLearner
    private let sessionPlanner: SessionPlanner
    private let biometricCrossfade = BiometricCrossfadeEngine()
    private let workoutBPMAdvisor = WorkoutBPMAdvisor()

    /// Real-time guard adjuster for biometric-aware filtering
    var guardAdjuster: RealTimeGuardAdjuster?

    /// Context collector for accessing latest biometric signal. Set externally after init.
    var contextCollector: ContextCollector?

    /// State engine for resting HR and personal HRV baseline. Set externally after init.
    var stateEngine: StateEngine?

    // MARK: - Session Tracking

    /// Songs played in the current session (ordered, most recent last).
    private var sessionSongIds: [UUID] = []

    /// Artist names played in the current session (ordered, most recent last).
    private var sessionArtists: [String] = []

    /// Recently played songs with timestamps for recency filtering.
    private var recentlyPlayed: [UUID: Date] = [:]

    /// The last played song's UUID (for transition logic).
    private var lastPlayedSongId: UUID?

    // MARK: - Session Arc State (WS-4)

    /// The currently active session arc, if any.
    private(set) var currentArc: SessionArc?

    /// Number of songs played in the current arc.
    private(set) var arcSongsPlayed = 0

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        self.songScorer = SongScorer()
        self.guardFilters = GuardFilters()
        self.transitionController = TransitionController()
        self.explanationGenerator = ExplanationGenerator()
        self.effectivenessLearner = EffectivenessLearner(persistence: persistence)
        self.sessionPlanner = SessionPlanner()

        logInfo("DecisionEngine initialized", category: .decisionEngine)
    }

    // MARK: - Main Decision Pipeline

    /// Selects the next song to play from the active playlist.
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

        // 1. Fetch candidate songs from the playlist (with optional cross-playlist pool)
        var candidates = fetchCandidateSongs(playlistId: playlistId, in: context)

        guard !candidates.isEmpty else {
            logWarning("DecisionEngine: no candidate songs found in playlist '\(playlistName)'", category: .decisionEngine)
            return nil
        }

        let primaryCount = candidates.count
        var crossPlaylistSongIds = Set<UUID>()

        if preferences.allowCrossPlaylistRecommendations {
            let crossPlaylistCandidates = fetchCrossPlaylistSongs(
                excludingIds: candidates.compactMap { $0.id },
                in: context
            )
            crossPlaylistSongIds = Set(crossPlaylistCandidates.compactMap { $0.id })
            candidates.append(contentsOf: crossPlaylistCandidates)
            logDebug(
                "DecisionEngine: cross-playlist enabled, added \(crossPlaylistCandidates.count) extra candidates",
                category: .decisionEngine
            )
        }

        logDebug("DecisionEngine: \(candidates.count) candidate songs loaded (\(primaryCount) primary)", category: .decisionEngine)

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

        // Initialize session arc on first song or context change (WS-4).
        // D1 fix: When a mood trajectory is active (from MoodTabView),
        // use planTrajectoryArc so the session arc follows the user's
        // intended mood journey rather than the default context-based plan.
        if let trajectory = stateEngine?.moodTrajectory {
            currentArc = sessionPlanner.planTrajectoryArc(trajectory: trajectory)
            arcSongsPlayed = 0
        } else if currentArc == nil || decisionContext.isSessionStart {
            currentArc = sessionPlanner.planSession(
                currentState: stateVector, targetContext: stateVector.context, estimatedDuration: 30)
            arcSongsPlayed = 0
        }
        let currentArcPhase = currentArc.map { sessionPlanner.currentPhase(for: $0, songsPlayed: arcSongsPlayed) }

        // Resolve workout BPM range if the user is currently in a workout.
        // The WorkoutBPMAdvisor maps HKWorkoutActivityType to optimal BPM ranges.
        let workoutRange: WorkoutBPMRange? = {
            guard stateVector.context == .workout,
                  let workoutName = contextCollector?.latestBiometric?.workoutType else {
                return nil
            }
            return workoutBPMAdvisor.targetBPMRange(forWorkoutName: workoutName)
        }()

        // 3. Score all remaining candidates (with arc phase overlay + workout BPM)
        var scores = songScorer.scoreAllCandidates(
            filterResult.accepted,
            context: decisionContext,
            arcPhase: currentArcPhase,
            workoutBPMRange: workoutRange
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

        // 3a. Apply 10% score reduction to cross-playlist candidates
        if !crossPlaylistSongIds.isEmpty {
            scores = scores.map { score in
                guard crossPlaylistSongIds.contains(score.songId) else { return score }
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
                    finalScore: score.finalScore * 0.9,
                    confidence: score.confidence,
                    explanationComponents: score.explanationComponents
                )
            }.sorted { $0.finalScore > $1.finalScore }
        }

        // 3b. Pass top candidates through EffectivenessLearner for exploration/exploitation
        if !scores.isEmpty {
            let topCount = min(scores.count, 20)
            let topCandidates = scores.prefix(topCount).map { score in
                (songId: score.songId, baseScore: score.finalScore)
            }
            let contextType = stateVector.context.rawValue
            let rlRanked = effectivenessLearner.scoreWithExploration(
                candidates: topCandidates,
                contextType: contextType,
                explorationBias: preferences.explorationBias
            )

            // Rebuild scores array with RL-adjusted ordering
            var scoresBySongId: [UUID: SongScore] = [:]
            for score in scores {
                scoresBySongId[score.songId] = score
            }

            var reorderedScores: [SongScore] = []
            for rlResult in rlRanked {
                if let original = scoresBySongId[rlResult.songId] {
                    // Create updated SongScore with RL-adjusted finalScore
                    let adjusted = SongScore(
                        songId: original.songId,
                        songTitle: original.songTitle,
                        artistName: original.artistName,
                        albumName: original.albumName,
                        bpm: original.bpm,
                        bpmMatchScore: original.bpmMatchScore,
                        energyMatchScore: original.energyMatchScore,
                        familiarityScore: original.familiarityScore,
                        historicalEffectScore: original.historicalEffectScore,
                        contextAlignmentScore: original.contextAlignmentScore,
                        recencyPenalty: original.recencyPenalty,
                        timeOfDayScore: original.timeOfDayScore,
                        finalScore: rlResult.adjustedScore,
                        confidence: original.confidence,
                        explanationComponents: original.explanationComponents
                    )
                    reorderedScores.append(adjusted)
                    scoresBySongId.removeValue(forKey: rlResult.songId)
                }
            }
            // Append remaining scores that were not in the top-N
            let remaining = scoresBySongId.values.sorted { $0.finalScore > $1.finalScore }
            reorderedScores.append(contentsOf: remaining)
            scores = reorderedScores
        }

        let lastPlayedSong = fetchLastPlayedSong(in: context)

        guard !scores.isEmpty else {
            logWarning("DecisionEngine: scoring produced no results", category: .decisionEngine)
            return nil
        }

        // 4. Apply transition logic
        // Build a lookup from the already-fetched candidate songs to avoid
        // a redundant Core Data fetch inside TransitionController.
        let candidateSongLookup: [UUID: Song] = {
            var lookup = [UUID: Song]()
            for song in candidates {
                if let id = song.id {
                    lookup[id] = song
                }
            }
            return lookup
        }()

        let selectedScore: SongScore
        if let transitioned = transitionController.selectWithTransition(
            candidates: scores,
            candidateSongs: candidateSongLookup,
            lastPlayedSong: lastPlayedSong,
            enableSmoothTransitions: preferences.enableSmoothTransitions
        ) {
            selectedScore = transitioned
        } else {
            selectedScore = scores[0]
        }

        // 5. Generate explanation (with cross-playlist attribution if applicable)
        var explanation = explanationGenerator.generate(
            score: selectedScore,
            state: stateVector,
            isSessionStart: decisionContext.isSessionStart
        )

        if crossPlaylistSongIds.contains(selectedScore.songId) {
            let sourcePlaylistName = lookupPlaylistName(for: selectedScore.songId, excluding: playlistId, in: context)
            let suffix = sourcePlaylistName.map { " (from \($0))" } ?? " (from another playlist)"
            explanation = SongExplanation(
                full: explanation.full + suffix,
                short: explanation.short + suffix,
                factors: explanation.factors,
                stateDescription: explanation.stateDescription,
                needDescription: explanation.needDescription
            )
        }

        // 6. Compute biometric-adaptive crossfade parameters
        let crossfade: CrossfadeParameters
        if preferences.biometricCrossfadeEnabled {
            let latestBiometric = contextCollector?.latestBiometric
            let restingHR = stateEngine?.restingHeartRate
            let maxHR: Double? = {
                if let vo2 = stateEngine?.cachedVO2Max, vo2 > 0 {
                    // Uth et al. formula: MaxHR ≈ 15.3 × VO2Max / 3.5
                    // Simplified: MaxHR ≈ 15.3 × (VO2Max / 3.5)
                    return 15.3 * (vo2 / 3.5)
                }
                return nil
            }()
            let hrvBaseline = stateEngine?.personalBaseline.baselineValue
                ?? PersonalBaseline.populationDefault

            crossfade = biometricCrossfade.computeCrossfadeParameters(
                biometric: latestBiometric,
                restingHeartRate: restingHR,
                maxHeartRate: maxHR,
                personalHRVBaseline: hrvBaseline,
                stateVector: stateVector,
                defaultDuration: preferences.crossfadeDuration
            )
            logDebug(
                "DecisionEngine: crossfade \(crossfade.zone.rawValue) "
                + "(\(String(format: "%.1f", crossfade.duration))s, "
                + "conf: \(String(format: "%.2f", crossfade.confidence)))",
                category: .decisionEngine
            )
        } else {
            crossfade = CrossfadeParameters(
                duration: preferences.crossfadeDuration,
                confidence: 0.0,
                reason: "Biometric crossfade disabled",
                zone: .unknown
            )
        }

        // 7. Build result
        let result = DecisionResult(
            songId: selectedScore.songId,
            score: selectedScore,
            explanation: explanation,
            candidatesConsidered: filterResult.totalCandidates,
            candidatesFiltered: filterResult.rejected.count,
            crossfadeParameters: crossfade
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

    // MARK: - Feedback / Reward

    /// Processes feedback for a completed or skipped song, updating the
    /// EffectivenessLearner's reward model.
    ///
    /// - Parameters:
    ///   - songId: The UUID of the song that was played.
    ///   - reward: The playback reward signal (biometric + behavioral).
    ///   - musicNeed: The MusicNeed that was active when the song was selected.
    ///   - contextType: The activity context when the song was played (e.g. "workout").
    func processSongFeedback(
        songId: UUID,
        reward: PlaybackReward,
        musicNeed: MusicNeed,
        contextType: String = "any"
    ) {
        Task {
            await effectivenessLearner.processReward(
                songId: songId,
                contextType: contextType,
                reward: reward,
                musicNeed: musicNeed
            )
            logDebug(
                "DecisionEngine: forwarded reward to EffectivenessLearner for song \(songId)",
                category: .decisionEngine
            )
        }
    }

    /// Saves exploration parameters to UserDefaults for persistence across
    /// app lifecycle events.
    func persistLearnerState() {
        effectivenessLearner.saveExplorationState()
    }

    // MARK: - Session Management

    /// Resets the session tracking (e.g., when a new playlist is selected).
    func resetSession() {
        sessionSongIds.removeAll()
        sessionArtists.removeAll()
        recentlyPlayed.removeAll()
        lastPlayedSongId = nil
        lastDecision = nil
        currentArc = nil
        arcSongsPlayed = 0
        biometricCrossfade.reset()
        logInfo("DecisionEngine: session reset", category: .decisionEngine)
    }

    // MARK: - Session Arc Accessors (WS-4)

    /// Returns the current DJ energy level (1-10) based on arc progress.
    var currentDJEnergyLevel: Int {
        guard let arc = currentArc else { return 5 }
        return arc.djEnergyLevel(at: arcSongsPlayed)
    }

    /// Returns the planned energy trajectory for visualization.
    var arcEnergyTrajectory: [(songIndex: Int, energy: Double)] {
        currentArc?.energyTrajectory ?? []
    }

    // MARK: - Queue Precomputation

    /// Precomputes the top N songs for the up-next queue.
    ///
    /// Runs the full scoring pipeline (guard filters, song scorer, arc phase,
    /// exploration/exploitation, transition smoothing) but does NOT mutate
    /// session state -- songs are scored as if they were candidates for the
    /// *next* selection, not consumed. This means the queue is a snapshot
    /// prediction that remains valid until state changes significantly.
    ///
    /// - Parameters:
    ///   - count: How many queue items to return (default 10, capped at 25).
    ///   - playlistId: Active playlist UUID.
    ///   - playlistName: Active playlist display name.
    ///   - stateVector: Current user state.
    ///   - preferences: User preferences (weights, exploration bias, etc.).
    /// - Returns: An array of `QueueItem` ordered by predicted play order,
    ///   or an empty array if no candidates are available.
    func precomputeQueue(
        count: Int = 10,
        playlistId: UUID,
        playlistName: String,
        stateVector: StateVector,
        preferences: UserPreferences = .load()
    ) async -> [QueueItem] {
        let cappedCount = min(max(count, 1), 25)

        let context = persistence.viewContext

        // 1. Fetch candidates
        let candidates = fetchCandidateSongs(playlistId: playlistId, in: context)
        guard !candidates.isEmpty else {
            logDebug("precomputeQueue: no candidates in playlist", category: .decisionEngine)
            return []
        }

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

        // 2. Guard filters (same as selectNextSong but read-only)
        let filterResult = guardFilters.apply(
            candidates: candidates,
            context: decisionContext,
            recentArtists: sessionArtists
        )

        let scoringPool = filterResult.accepted.isEmpty ? candidates : filterResult.accepted

        // 3. Resolve arc phase for scoring
        let currentArcPhase = currentArc.map {
            sessionPlanner.currentPhase(for: $0, songsPlayed: arcSongsPlayed)
        }

        // 4. Score all candidates
        var scores = songScorer.scoreAllCandidates(
            scoringPool,
            context: decisionContext,
            arcPhase: currentArcPhase
        )

        // 4b. Apply RL exploration/exploitation reranking (mirrors selectNextSong step 3b)
        if !scores.isEmpty {
            let topCount = min(scores.count, 20)
            let topCandidates = scores.prefix(topCount).map { score in
                (songId: score.songId, baseScore: score.finalScore)
            }
            let contextType = stateVector.context.rawValue
            let rlRanked = effectivenessLearner.scoreWithExploration(
                candidates: topCandidates,
                contextType: contextType,
                explorationBias: preferences.explorationBias
            )

            var scoresBySongId: [UUID: SongScore] = [:]
            for score in scores { scoresBySongId[score.songId] = score }

            var reordered: [SongScore] = []
            for rlResult in rlRanked {
                if let original = scoresBySongId[rlResult.songId] {
                    let adjusted = SongScore(
                        songId: original.songId, songTitle: original.songTitle,
                        artistName: original.artistName, albumName: original.albumName,
                        bpm: original.bpm, bpmMatchScore: original.bpmMatchScore,
                        energyMatchScore: original.energyMatchScore,
                        familiarityScore: original.familiarityScore,
                        historicalEffectScore: original.historicalEffectScore,
                        contextAlignmentScore: original.contextAlignmentScore,
                        recencyPenalty: original.recencyPenalty,
                        timeOfDayScore: original.timeOfDayScore,
                        finalScore: rlResult.adjustedScore,
                        confidence: original.confidence,
                        explanationComponents: original.explanationComponents
                    )
                    reordered.append(adjusted)
                    scoresBySongId.removeValue(forKey: rlResult.songId)
                }
            }
            reordered.append(contentsOf: scoresBySongId.values.sorted { $0.finalScore > $1.finalScore })
            scores = reordered
        }

        // 5. Take top N and build QueueItems
        let topScores = Array(scores.prefix(cappedCount))

        // Batch-resolve Apple Music IDs from Core Data
        let songIdToAppleMusicId = resolveAppleMusicIds(
            for: topScores.map(\.songId),
            in: context
        )

        let items: [QueueItem] = topScores.enumerated().map { index, score in
            let shortExplanation = explanationGenerator.generate(
                score: score,
                state: stateVector,
                isSessionStart: false
            ).short

            return QueueItem(
                songScore: score,
                shortExplanation: shortExplanation,
                appleMusicId: songIdToAppleMusicId[score.songId] ?? "",
                position: index + 1
            )
        }

        logInfo(
            "precomputeQueue: built \(items.count) queue items "
            + "(from \(scoringPool.count) candidates, top score: "
            + "\(String(format: "%.3f", topScores.first?.finalScore ?? 0)))",
            category: .decisionEngine
        )

        return items
    }

    /// Resolves Core Data Song UUIDs to their Apple Music IDs in a single
    /// batch fetch, avoiding N+1 queries.
    private func resolveAppleMusicIds(
        for songIds: [UUID],
        in context: NSManagedObjectContext
    ) -> [UUID: String] {
        guard !songIds.isEmpty else { return [:] }
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "id IN %@", songIds as CVarArg)
        request.propertiesToFetch = ["id", "appleMusicId"]

        guard let songs = try? context.fetch(request) else { return [:] }

        var result: [UUID: String] = [:]
        for song in songs {
            if let id = song.id, let amId = song.appleMusicId, !amId.isEmpty {
                result[id] = amId
            }
        }
        return result
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

    /// Fetches songs from other playlists that are not in the primary candidate set.
    /// Only returns songs with a minimum confidence level to ensure quality cross-playlist picks.
    private func fetchCrossPlaylistSongs(
        excludingIds: [UUID],
        in context: NSManagedObjectContext
    ) -> [Song] {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "NOT (id IN %@) AND confidenceLevel >= 0.3", excludingIds as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        request.fetchLimit = 200
        request.fetchBatchSize = 50

        do {
            return try context.fetch(request)
        } catch {
            logError("DecisionEngine: failed to fetch cross-playlist songs", error: error, category: .decisionEngine)
            return []
        }
    }

    /// Looks up the name of a playlist that contains the given song, excluding the active playlist.
    private func lookupPlaylistName(
        for songId: UUID,
        excluding activePlaylistId: UUID,
        in context: NSManagedObjectContext
    ) -> String? {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "id == %@", songId as CVarArg)
        request.fetchLimit = 1
        request.relationshipKeyPathsForPrefetching = ["playlists"]

        guard let song = try? context.fetch(request).first,
              let playlists = song.playlists as? Set<NSManagedObject> else {
            return nil
        }

        for playlist in playlists {
            if let plId = playlist.value(forKey: "id") as? UUID,
               plId != activePlaylistId,
               let name = playlist.value(forKey: "name") as? String {
                return name
            }
        }
        return nil
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
        arcSongsPlayed += 1
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
            candidatesFiltered: 0,
            crossfadeParameters: CrossfadeParameters(
                duration: context.preferences.crossfadeDuration,
                confidence: 0.0,
                reason: "Fallback crossfade (user preference)",
                zone: .unknown
            )
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

    // MARK: - E1: ADHD Focus Mode

    /// Whether ADHD focus mode is currently active.
    private var isADHDFocusActive = false

    /// Activates ADHD-optimized scoring: high-familiarity, low-novelty selections.
    func activateADHDFocus() {
        isADHDFocusActive = true
        logInfo("DecisionEngine: ADHD focus mode activated", category: .decisionEngine)
    }

    /// Deactivates ADHD focus mode.
    func deactivateADHDFocus() {
        isADHDFocusActive = false
        logInfo("DecisionEngine: ADHD focus mode deactivated", category: .decisionEngine)
    }

    // MARK: - E3: NL Scoring Overrides

    /// Active natural language scoring overrides, if any.
    private var scoringOverrides: ScoringOverrides?

    /// Applies temporary NL scoring overrides from NaturalLanguageDJService.
    func applyScoringOverrides(_ overrides: ScoringOverrides) {
        scoringOverrides = overrides
        logInfo(
            "DecisionEngine: NL scoring overrides applied for \(overrides.remainingSongs) songs",
            category: .decisionEngine
        )
    }

    /// Clears any active NL scoring overrides.
    func clearScoringOverrides() {
        scoringOverrides = nil
        logInfo("DecisionEngine: NL scoring overrides cleared", category: .decisionEngine)
    }
}

#endif
