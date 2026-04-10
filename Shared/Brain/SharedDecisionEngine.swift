//
//  DecisionEngine.swift
//  Resonance
//
//  Orchestrates song selection by combining StateEngine signals with
//  SongScorer rankings. Implements the iso-principle (match-then-shift)
//  for smooth physiological transitions (6.3).
//  Integrates SessionPlanner for multi-song arc planning (WS-4).
//

import Foundation

// MARK: - SharedDecisionEngine

/// Orchestrates the song selection pipeline:
/// 1. Receives a DecisionContext (state + candidates)
/// 2. Queries the SessionPlanner for the current ArcPhase target
/// 3. Scores all candidate songs via SharedSongScorer (with arc phase overlay)
/// 4. Applies iso-principle logic for session transitions (6.3)
/// 5. Returns ranked SongScores with the top pick
///
/// The iso-principle (6.3) ensures that at session start or context change,
/// the first 1-2 songs match the user's current arousal-derived BPM before
/// gradually shifting toward the therapeutic target.
///
/// The SessionPlanner (WS-4) provides a session-level arc that overrides
/// per-song target BPM when active, giving the DJ a longer-horizon plan.
public final class SharedDecisionEngine: @unchecked Sendable {

    // MARK: - Lock for Thread Safety

    private let lock = NSLock()

    // MARK: - Dependencies

    private let scorer: SharedSongScorer
    private let stateEngine: SharedStateEngine
    private let sessionPlanner: SessionPlanner

    // MARK: - Session Arc State (WS-4)
    // All mutable state below is protected by `lock`.

    /// The currently active session arc, if any.
    private var _currentArc: SessionArc?

    /// Number of songs played in the current arc.
    private var _arcSongsPlayed = 0

    // MARK: - Iso-Principle State (6.3)

    /// Whether iso mode is currently active (first 1-2 songs of a session/context change).
    private var _isIsoModeActive = false

    /// Number of songs played since iso mode was activated.
    private var _isoModeSongCount = 0

    /// Number of songs to play in iso mode before transitioning.
    private let isoModeDuration = 2

    /// The BPM target during iso mode (matches current arousal).
    private var _isoTargetBPM: Double?

    /// The context that was active when iso mode started.
    private var _isoModeStartContext: ActivityContext?

    /// BPM of the most recently selected song (for transition tracking).
    private var _lastSelectedBPM: Double?

    /// Session song count at last decision (to detect session resets).
    private var _lastSessionSongCount = 0

    // MARK: - Iso-Principle Transition Rates

    /// Perceptual shift mode (existing): used for user-initiated context changes.
    /// BPM change per song when activating (shifting up).
    private let perceptualActivationRate: ClosedRange<Double> = 5.0...8.0

    /// Perceptual shift mode: BPM change per song when deactivating (shifting down).
    private let perceptualDeactivationRate: ClosedRange<Double> = 5.0...10.0

    // R4: Entrainment-mode ISO principle rates (new).
    // Used for Brain-initiated stress reduction when stress > 0.7.
    // Research: successful physiological entrainment requires ~2% tempo
    // change per song (~2-3 BPM). Larger shifts break the entrainment
    // coupling and reduce calming effectiveness.
    // Reference: Thaut, Rhythm, Music and the Brain 2005;
    //            Ellis & Thayer, Music Perception 2010

    /// Entrainment mode: BPM change per song when activating (shifting up).
    private let entrainmentActivationRate: ClosedRange<Double> = 2.0...3.0

    /// Entrainment mode: BPM change per song when deactivating (shifting down).
    private let entrainmentDeactivationRate: ClosedRange<Double> = 2.0...3.0

    /// Whether the engine should use entrainment (gentle) rates for the current transition.
    /// True when stress > 0.7 and the Brain is doing calming autonomously.
    private var _useEntrainmentMode = false

    // MARK: - E1: ADHD Focus Mode

    /// Whether ADHD focus mode is currently active.
    private var _isADHDFocusActive = false

    /// Set to true when the FocusStateDetector fires a distraction callback,
    /// signalling that the next song selection should use emergency weights.
    private var _distractionTriggeredRescore = false

    // MARK: - E3: NL Scoring Overrides

    /// Temporary scoring weight overrides from NL commands (E3).
    /// When non-nil and not expired, overrides apply to each selectSong call.
    private var _scoringOverrides: ScoringOverrides?

    // MARK: - Thread-Safe Accessors

    /// The currently active session arc, if any.
    public var currentArc: SessionArc? { lock.withLock { _currentArc } }

    /// Number of songs played in the current arc.
    public var arcSongsPlayed: Int { lock.withLock { _arcSongsPlayed } }

    /// Whether iso mode is currently active.
    public var isIsoModeActive: Bool { lock.withLock { _isIsoModeActive } }

    /// The BPM target during iso mode.
    public var isoTargetBPM: Double? { lock.withLock { _isoTargetBPM } }

    /// BPM of the most recently selected song.
    public var lastSelectedBPM: Double? { lock.withLock { _lastSelectedBPM } }

    /// Whether ADHD focus mode is currently active (E1).
    public var isADHDFocusActive: Bool { lock.withLock { _isADHDFocusActive } }

    /// Current NL scoring overrides, if any (E3).
    public var scoringOverrides: ScoringOverrides? { lock.withLock { _scoringOverrides } }

    // MARK: - Initialization

    public init(
        stateEngine: SharedStateEngine,
        scorer: SharedSongScorer = SharedSongScorer(),
        sessionPlanner: SessionPlanner = SessionPlanner()
    ) {
        self.stateEngine = stateEngine
        self.scorer = scorer
        self.sessionPlanner = sessionPlanner

        logInfo("SharedDecisionEngine initialized", category: .decisionEngine)
    }

    // MARK: - Public API

    /// Selects the best song from candidates in the given context.
    /// Returns scored and ranked candidates (highest score first).
    ///
    /// When a session arc is active, the current ArcPhase is queried
    /// and passed to the SharedSongScorer to override target BPM/energy.
    public func selectSong(
        context: DecisionContext,
        candidateFeatures: [(id: UUID, title: String, artist: String, album: String,
                             features: SongFeatures, playCount: Int)]
    ) -> [SongScore] {
        let perfLog = PerformanceLogger("SharedDecisionEngine.selectSong", category: .decisionEngine)
        defer { perfLog.end() }

        // Read stateEngine properties outside the lock (stateEngine has its own synchronization)
        let arousalState = stateEngine.arousalState
        let isSleepPrep = stateEngine.isSleepPrepActive
        let bpmAdjustment = stateEngine.arousalBPMAdjustment

        return lock.withLock {
            // Detect session start or context change -> enter iso mode (6.3)
            _updateIsoModeState(context: context)

            // Initialize session arc on session start (WS-4)
            if context.isSessionStart || _currentArc == nil {
                _startSessionArc(context: context)
            }

            // Calculate the effective iso target BPM for this selection
            let effectiveIsoTargetBPM = _calculateEffectiveIsoTargetBPM(context: context)

            // Query the current arc phase for this song position (WS-4)
            let currentArcPhase: ArcPhase?
            if let arc = _currentArc {
                currentArcPhase = sessionPlanner.currentPhase(for: arc, songsPlayed: _arcSongsPlayed)
            } else {
                currentArcPhase = nil
            }

            // E1: Determine ADHD focus mode for this scoring pass
            let adhdFocusActive = _isADHDFocusActive

            // E1: When distraction was detected, apply emergency weight overrides.
            // These temporarily boost familiarity and historical weights to anchor
            // the listener with highly familiar music during attentional disruption.
            var effectiveContext = context
            if _distractionTriggeredRescore && adhdFocusActive {
                var emergencyPrefs = context.preferences
                emergencyPrefs.familiarityWeight = 0.40
                emergencyPrefs.historicalWeight = 0.35
                // Redistribute remaining weight proportionally among other factors
                let remaining = 1.0 - 0.40 - 0.35  // 0.25
                emergencyPrefs.bpmWeight = 0.08
                emergencyPrefs.energyWeight = 0.10
                emergencyPrefs.contextWeight = 0.07
                effectiveContext = DecisionContext(
                    stateVector: context.stateVector,
                    activePlaylistId: context.activePlaylistId,
                    activePlaylistName: context.activePlaylistName,
                    candidateSongIds: context.candidateSongIds,
                    recentlyPlayed: context.recentlyPlayed,
                    currentTime: context.currentTime,
                    currentSessionSongIds: context.currentSessionSongIds,
                    preferences: emergencyPrefs,
                    isSessionStart: context.isSessionStart,
                    moodTrajectory: context.moodTrajectory
                )
                _distractionTriggeredRescore = false

                logInfo(
                    "SharedDecisionEngine: distraction emergency weights applied "
                    + "(fam=0.40, hist=0.35)",
                    category: .decisionEngine
                )
            }

            // E3: Apply NL scoring overrides if active and not expired
            if var overrides = _scoringOverrides, !overrides.isExpired {
                var overriddenPrefs = effectiveContext.preferences
                if let bw = overrides.bpmWeight { overriddenPrefs.bpmWeight = bw }
                if let ew = overrides.energyWeight { overriddenPrefs.energyWeight = ew }
                if let fw = overrides.familiarityWeight { overriddenPrefs.familiarityWeight = fw }
                if let hw = overrides.historicalWeight { overriddenPrefs.historicalWeight = hw }
                if let cw = overrides.contextWeight { overriddenPrefs.contextWeight = cw }
                if let eb = overrides.explorationBias { overriddenPrefs.explorationBias = eb }
                effectiveContext = DecisionContext(
                    stateVector: effectiveContext.stateVector,
                    activePlaylistId: effectiveContext.activePlaylistId,
                    activePlaylistName: effectiveContext.activePlaylistName,
                    candidateSongIds: effectiveContext.candidateSongIds,
                    recentlyPlayed: effectiveContext.recentlyPlayed,
                    currentTime: effectiveContext.currentTime,
                    currentSessionSongIds: effectiveContext.currentSessionSongIds,
                    preferences: overriddenPrefs,
                    isSessionStart: effectiveContext.isSessionStart,
                    moodTrajectory: effectiveContext.moodTrajectory
                )
                // Decrement remaining songs
                _scoringOverrides = overrides.decremented()
                if _scoringOverrides?.isExpired == true {
                    _scoringOverrides = nil
                    logInfo(
                        "SharedDecisionEngine: NL scoring overrides expired",
                        category: .decisionEngine
                    )
                }
            }

            // Score all candidates, passing the arc phase to the scorer
            var scores = candidateFeatures.map { candidate in
                scorer.score(
                    songId: candidate.id,
                    songTitle: candidate.title,
                    artistName: candidate.artist,
                    albumName: candidate.album,
                    features: candidate.features,
                    playCount: candidate.playCount,
                    context: effectiveContext,
                    arousalState: arousalState,
                    isSleepPrepActive: isSleepPrep,
                    arousalBPMAdjustment: bpmAdjustment,
                    isoModeActive: _isIsoModeActive,
                    isoTargetBPM: effectiveIsoTargetBPM,
                    arcPhase: currentArcPhase,
                    isADHDFocusMode: adhdFocusActive
                )
            }

            // Sort descending by final score
            scores.sort { $0.finalScore > $1.finalScore }

            // Apply transition smoothing if not in iso mode
            if !_isIsoModeActive, let lastBPM = _lastSelectedBPM, context.preferences.enableSmoothTransitions {
                scores = applyTransitionSmoothing(scores: scores, lastBPM: lastBPM)
            }

            // Track the selected song's BPM and arc progress
            if let topScore = scores.first {
                _lastSelectedBPM = topScore.bpm
                if _isIsoModeActive {
                    _isoModeSongCount += 1
                }
                _arcSongsPlayed += 1
            }

            _lastSessionSongCount = context.sessionSongCount

            logDebug(
                "SharedDecisionEngine: scored \(scores.count) candidates, "
                + "top=\(scores.first?.songTitle ?? "none") "
                + "(score=\(String(format: "%.3f", scores.first?.finalScore ?? 0))), "
                + "isoMode=\(_isIsoModeActive), isoCount=\(_isoModeSongCount), "
                + "adhdFocus=\(adhdFocusActive), "
                + "arcPhase=\(currentArcPhase?.phase.rawValue ?? "none"), "
                + "arcSong=\(_arcSongsPlayed)",
                category: .decisionEngine
            )

            return scores
        }
    }

    /// Resets the engine state (e.g., on session end).
    public func reset() {
        lock.withLock {
            _isIsoModeActive = false
            _isoModeSongCount = 0
            _isoTargetBPM = nil
            _isoModeStartContext = nil
            _lastSelectedBPM = nil
            _lastSessionSongCount = 0
            _currentArc = nil
            _arcSongsPlayed = 0
            _useEntrainmentMode = false
            _isADHDFocusActive = false
            _distractionTriggeredRescore = false
            _scoringOverrides = nil
        }
        stateEngine.focusDetector.clearDistractionCallback()
        logInfo("SharedDecisionEngine: state reset", category: .decisionEngine)
    }

    // MARK: - E1: ADHD Focus Mode

    /// Activates ADHD focus mode. Registers a distraction callback on the
    /// state engine's focus detector so that distraction events trigger
    /// emergency re-scoring with high familiarity weights.
    public func activateADHDFocus() {
        lock.withLock {
            _isADHDFocusActive = true
            _distractionTriggeredRescore = false
        }

        // Register distraction callback (focusDetector is thread-safe via stateEngine's lock)
        stateEngine.focusDetector.setDistractionCallback { [weak self] in
            self?.handleDistractionDetected()
        }

        logInfo("SharedDecisionEngine: ADHD focus mode activated", category: .decisionEngine)
    }

    /// Deactivates ADHD focus mode and clears the distraction callback.
    public func deactivateADHDFocus() {
        lock.withLock {
            _isADHDFocusActive = false
            _distractionTriggeredRescore = false
        }

        stateEngine.focusDetector.clearDistractionCallback()

        logInfo("SharedDecisionEngine: ADHD focus mode deactivated", category: .decisionEngine)
    }

    /// Called by the FocusStateDetector when a distraction event is detected.
    /// Sets a flag so the next selectSong call uses emergency weights.
    private func handleDistractionDetected() {
        lock.withLock {
            _distractionTriggeredRescore = true
        }

        logInfo(
            "SharedDecisionEngine: distraction detected, emergency rescore queued",
            category: .decisionEngine
        )
    }

    // MARK: - E3: NL Scoring Overrides

    /// Applies temporary NL scoring overrides. The overrides will be active
    /// for `overrides.remainingSongs` song selections, then auto-expire.
    public func applyScoringOverrides(_ overrides: ScoringOverrides) {
        lock.withLock {
            _scoringOverrides = overrides
        }

        logInfo(
            "SharedDecisionEngine: NL scoring overrides applied "
            + "for \(overrides.remainingSongs) songs: \(overrides.description)",
            category: .decisionEngine
        )
    }

    /// Clears any active NL scoring overrides immediately.
    public func clearScoringOverrides() {
        lock.withLock {
            _scoringOverrides = nil
        }

        logInfo("SharedDecisionEngine: NL scoring overrides cleared", category: .decisionEngine)
    }

    // MARK: - Session Arc Management (WS-4)

    /// Starts a new session arc based on the current context.
    /// Called automatically on session start or when no arc exists.
    /// D1 fix: When a mood trajectory is present in the context, uses
    /// `planTrajectoryArc` for guided mood journeys.
    public func startSessionArc(
        context: DecisionContext,
        estimatedDuration: TimeInterval = 30
    ) {
        let arc: SessionArc
        if let trajectory = context.moodTrajectory {
            arc = sessionPlanner.planTrajectoryArc(trajectory: trajectory)
        } else {
            arc = sessionPlanner.planSession(
                currentState: context.stateVector,
                targetContext: context.stateVector.context,
                estimatedDuration: estimatedDuration
            )
        }
        lock.withLock {
            _currentArc = arc
            _arcSongsPlayed = 0
        }

        logInfo(
            "SharedDecisionEngine: started session arc template=\(arc.template.rawValue), "
            + "phases=\(arc.phases.count), totalSongs=\(arc.totalSongs)",
            category: .decisionEngine
        )
    }

    /// Internal version called while holding `lock`.
    /// D1 fix: When a mood trajectory is present in the context, uses
    /// `planTrajectoryArc` so the session follows the user's intended
    /// mood journey rather than the default context-based plan.
    private func _startSessionArc(
        context: DecisionContext,
        estimatedDuration: TimeInterval = 30
    ) {
        let arc: SessionArc
        if let trajectory = context.moodTrajectory {
            arc = sessionPlanner.planTrajectoryArc(trajectory: trajectory)
        } else {
            arc = sessionPlanner.planSession(
                currentState: context.stateVector,
                targetContext: context.stateVector.context,
                estimatedDuration: estimatedDuration
            )
        }
        _currentArc = arc
        _arcSongsPlayed = 0

        logInfo(
            "SharedDecisionEngine: started session arc template=\(arc.template.rawValue), "
            + "phases=\(arc.phases.count), totalSongs=\(arc.totalSongs)",
            category: .decisionEngine
        )
    }

    /// Returns the current DJ energy level (1-10) based on arc progress.
    /// Returns 5 (moderate) if no arc is active.
    public var currentDJEnergyLevel: Int {
        lock.withLock {
            guard let arc = _currentArc else { return 5 }
            return arc.djEnergyLevel(at: _arcSongsPlayed)
        }
    }

    /// Returns an array of (songIndex, energy) pairs representing the planned arc.
    /// Useful for the MoodArcView visualization.
    public var arcEnergyTrajectory: [(songIndex: Int, energy: Double)] {
        lock.withLock { _currentArc?.energyTrajectory ?? [] }
    }

    // MARK: - Iso-Principle Implementation (6.3)

    /// Updates iso-mode state based on session transitions and context changes.
    /// Must be called while holding `lock`.
    ///
    /// Enters iso mode when:
    /// 1. A new session starts (isSessionStart or sessionSongCount reset)
    /// 2. The activity context changes significantly
    ///
    /// During iso mode, the first 1-2 songs match the user's current
    /// arousal-derived BPM. Then subsequent songs gradually shift toward
    /// the therapeutic target.
    private func _updateIsoModeState(context: DecisionContext) {
        let currentContext = context.stateVector.context

        // Detect session start
        let isNewSession = context.isSessionStart
            || (context.sessionSongCount < _lastSessionSongCount)

        // Detect context change
        let isContextChange: Bool
        if let startContext = _isoModeStartContext {
            isContextChange = currentContext != startContext && !_isIsoModeActive
        } else {
            isContextChange = false
        }

        // Enter iso mode
        if isNewSession || isContextChange {
            _enterIsoMode(context: context)
            return
        }

        // Exit iso mode after playing enough songs
        if _isIsoModeActive && _isoModeSongCount >= isoModeDuration {
            _exitIsoMode()
        }
    }

    /// Activates iso mode: sets the target BPM to match current arousal.
    /// R4: When stress > 0.7 and the inferred need is .calm, uses entrainment
    /// mode with gentler BPM shift rates (~2-3 BPM/song) for successful
    /// physiological entrainment.
    /// Must be called while holding `lock`.
    private func _enterIsoMode(context: DecisionContext) {
        _isIsoModeActive = true
        _isoModeSongCount = 0
        _isoModeStartContext = context.stateVector.context

        // R4: Determine if entrainment mode should be used.
        // Brain-initiated calming (stress > 0.7) benefits from gentler tempo shifts.
        // Reference: Thaut, Rhythm, Music and the Brain 2005
        _useEntrainmentMode = context.stateVector.stress > 0.7
            && context.stateVector.inferredNeed == .calm

        // Derive BPM from current arousal level
        // arousal 0.0-1.0 maps to approximately 60-160 BPM
        let arousal = context.stateVector.arousal
        let arousalBPM = 60.0 + arousal * 100.0
        _isoTargetBPM = arousalBPM

        let modeLabel = _useEntrainmentMode ? "entrainment" : "perceptual"
        logInfo(
            "SharedDecisionEngine: entering iso mode (\(modeLabel)), "
            + "arousal=\(String(format: "%.2f", arousal)), "
            + "stress=\(String(format: "%.2f", context.stateVector.stress)), "
            + "isoBPM=\(Int(arousalBPM)), context=\(context.stateVector.context.rawValue)",
            category: .decisionEngine
        )
    }

    /// Deactivates iso mode, transitioning to normal target-based selection.
    /// Must be called while holding `lock`.
    private func _exitIsoMode() {
        _isIsoModeActive = false
        _isoTargetBPM = nil

        logInfo("SharedDecisionEngine: exiting iso mode after \(_isoModeSongCount) songs",
                category: .decisionEngine)
    }

    /// Calculates the effective target BPM during iso mode, implementing
    /// the gradual shift from arousal-matched BPM toward therapeutic target.
    /// Must be called while holding `lock`.
    ///
    /// R4: Uses two rate profiles:
    /// - Perceptual mode (user-initiated): +5 to +8 / -5 to -10 BPM per song
    /// - Entrainment mode (Brain-initiated calming): +2 to +3 / -2 to -3 BPM per song
    ///
    /// Entrainment mode activates when stress > 0.7 and the Brain is calming.
    /// Reference: Thaut, Rhythm, Music and the Brain 2005;
    ///            Ellis & Thayer, Music Perception 2010
    private func _calculateEffectiveIsoTargetBPM(context: DecisionContext) -> Double? {
        guard _isIsoModeActive, let baseBPM = _isoTargetBPM else { return nil }

        // During the first song, match exactly
        if _isoModeSongCount == 0 {
            return baseBPM
        }

        // Calculate the therapeutic target we're shifting toward
        let therapeuticTarget = calculateTherapeuticTargetBPM(
            need: context.stateVector.inferredNeed
        )

        // Determine direction and rate.
        // R4: Select rate profile based on entrainment mode.
        let bpmDifference = therapeuticTarget - baseBPM
        let isActivating = bpmDifference > 0

        let activeActivationRate: ClosedRange<Double>
        let activeDeactivationRate: ClosedRange<Double>

        if _useEntrainmentMode {
            // R4: Entrainment mode -- gentle ~2% tempo change per song
            activeActivationRate = entrainmentActivationRate
            activeDeactivationRate = entrainmentDeactivationRate
        } else {
            // Standard perceptual shift mode
            activeActivationRate = perceptualActivationRate
            activeDeactivationRate = perceptualDeactivationRate
        }

        let ratePerSong: Double
        if isActivating {
            ratePerSong = (activeActivationRate.lowerBound + activeActivationRate.upperBound) / 2.0
        } else {
            ratePerSong = -(activeDeactivationRate.lowerBound + activeDeactivationRate.upperBound) / 2.0
        }

        // Apply gradual shift
        let shiftedBPM = baseBPM + ratePerSong * Double(_isoModeSongCount)

        // Don't overshoot the therapeutic target
        if isActivating {
            return min(shiftedBPM, therapeuticTarget)
        } else {
            return max(shiftedBPM, therapeuticTarget)
        }
    }

    /// Returns the midpoint BPM for a given music need.
    private func calculateTherapeuticTargetBPM(need: MusicNeed) -> Double {
        let range: (min: Double, max: Double)
        switch need {
        case .energize: range = DecisionEngineConstants.BPMRange.energize
        case .calm: range = DecisionEngineConstants.BPMRange.calm
        case .focus: range = DecisionEngineConstants.BPMRange.focus
        case .maintain: range = DecisionEngineConstants.BPMRange.maintain
        case .transition: range = DecisionEngineConstants.BPMRange.transition
        }
        return (range.min + range.max) / 2.0
    }

    // MARK: - Transition Smoothing

    /// Reranks scores to favor smooth BPM transitions (avoid jarring jumps).
    private func applyTransitionSmoothing(
        scores: [SongScore],
        lastBPM: Double
    ) -> [SongScore] {
        // If the top candidate has a BPM jump > maxTransitionDelta,
        // prefer a candidate with smoother transition
        let maxDelta = DecisionEngineConstants.maxBPMTransitionDelta

        guard let topScore = scores.first else { return scores }

        let topBPMDelta = abs(topScore.bpm - lastBPM)
        if topBPMDelta <= maxDelta {
            return scores // Top choice is already smooth
        }

        // Find the best-scoring candidate within transition range
        if let smoothCandidate = scores.first(where: { abs($0.bpm - lastBPM) <= maxDelta }) {
            // Only swap if the smooth candidate's score is at least 70% of the top
            if smoothCandidate.finalScore >= topScore.finalScore * 0.7 {
                var reordered = scores
                if let idx = reordered.firstIndex(where: { $0.songId == smoothCandidate.songId }) {
                    reordered.remove(at: idx)
                    reordered.insert(smoothCandidate, at: 0)
                }
                return reordered
            }
        }

        return scores
    }
}
