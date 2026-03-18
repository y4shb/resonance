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
    private var _arcSongsPlayed: Int = 0

    // MARK: - Iso-Principle State (6.3)

    /// Whether iso mode is currently active (first 1-2 songs of a session/context change).
    private var _isIsoModeActive: Bool = false

    /// Number of songs played since iso mode was activated.
    private var _isoModeSongCount: Int = 0

    /// Number of songs to play in iso mode before transitioning.
    private let isoModeDuration: Int = 2

    /// The BPM target during iso mode (matches current arousal).
    private var _isoTargetBPM: Double?

    /// The context that was active when iso mode started.
    private var _isoModeStartContext: ActivityContext?

    /// BPM of the most recently selected song (for transition tracking).
    private var _lastSelectedBPM: Double?

    /// Session song count at last decision (to detect session resets).
    private var _lastSessionSongCount: Int = 0

    // MARK: - Iso-Principle Transition Rates

    /// BPM change per song when activating (shifting up).
    private let activationBPMRate: ClosedRange<Double> = 5.0...8.0

    /// BPM change per song when deactivating (shifting down).
    private let deactivationBPMRate: ClosedRange<Double> = 5.0...10.0

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

            // Score all candidates, passing the arc phase to the scorer
            var scores = candidateFeatures.map { candidate in
                scorer.score(
                    songId: candidate.id,
                    songTitle: candidate.title,
                    artistName: candidate.artist,
                    albumName: candidate.album,
                    features: candidate.features,
                    playCount: candidate.playCount,
                    context: context,
                    arousalState: arousalState,
                    isSleepPrepActive: isSleepPrep,
                    arousalBPMAdjustment: bpmAdjustment,
                    isoModeActive: _isIsoModeActive,
                    isoTargetBPM: effectiveIsoTargetBPM,
                    arcPhase: currentArcPhase
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
        }
        logInfo("SharedDecisionEngine: state reset", category: .decisionEngine)
    }

    // MARK: - Session Arc Management (WS-4)

    /// Starts a new session arc based on the current context.
    /// Called automatically on session start or when no arc exists.
    public func startSessionArc(
        context: DecisionContext,
        estimatedDuration: TimeInterval = 30
    ) {
        let arc = sessionPlanner.planSession(
            currentState: context.stateVector,
            targetContext: context.stateVector.context,
            estimatedDuration: estimatedDuration
        )
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
    private func _startSessionArc(
        context: DecisionContext,
        estimatedDuration: TimeInterval = 30
    ) {
        let arc = sessionPlanner.planSession(
            currentState: context.stateVector,
            targetContext: context.stateVector.context,
            estimatedDuration: estimatedDuration
        )
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
    /// Must be called while holding `lock`.
    private func _enterIsoMode(context: DecisionContext) {
        _isIsoModeActive = true
        _isoModeSongCount = 0
        _isoModeStartContext = context.stateVector.context

        // Derive BPM from current arousal level
        // arousal 0.0-1.0 maps to approximately 60-160 BPM
        let arousal = context.stateVector.arousal
        let arousalBPM = 60.0 + arousal * 100.0
        _isoTargetBPM = arousalBPM

        logInfo(
            "SharedDecisionEngine: entering iso mode, arousal=\(String(format: "%.2f", arousal)), "
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
    /// Transition rates:
    /// - Activation (energize): +5 to +8 BPM per song
    /// - Deactivation (calm): -5 to -10 BPM per song
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

        // Determine direction and rate
        let bpmDifference = therapeuticTarget - baseBPM
        let isActivating = bpmDifference > 0

        let ratePerSong: Double
        if isActivating {
            ratePerSong = (activationBPMRate.lowerBound + activationBPMRate.upperBound) / 2.0
        } else {
            ratePerSong = -(deactivationBPMRate.lowerBound + deactivationBPMRate.upperBound) / 2.0
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
