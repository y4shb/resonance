//
//  EmotionalRegulationEngine.swift
//  Resonance
//
//  Emotional Regulation Ladder (E6) using the ISO principle.
//  Detects negative emotional states and guides the user toward neutral
//  valence via incremental music shifting, gated by HRV verification.
//
//  References: Altshuler 1948; Appelhans & Luecken 2006; Saarikallio 2007
//  Related: MusicNeedInference.swift, StateCalculationHelpers.swift, SessionPlanner.swift
//

#if os(iOS)

import Foundation

// MARK: - Negative State Level

/// Severity of detected negative emotional state.
enum NegativeStateLevel: Int, CaseIterable, Comparable, Sendable {
    case neutral = 0
    case mildDistress = 1       // everyday frustration, minor HRV suppression
    case moderateDistress = 2   // sustained stress/sadness, significant HRV drop
    case acuteDistress = 3      // very low valence, severely depressed HRV + elevated HR

    static func < (lhs: NegativeStateLevel, rhs: NegativeStateLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Human-readable label for accessibility and logging.
    var displayName: String {
        switch self {
        case .neutral:          return "Neutral"
        case .mildDistress:     return "Mild Distress"
        case .moderateDistress: return "Moderate Distress"
        case .acuteDistress:    return "Acute Distress"
        }
    }

    /// Estimated number of rungs needed to reach neutral from this level.
    var estimatedRungs: Int {
        switch self {
        case .neutral:          return 0
        case .mildDistress:     return 2
        case .moderateDistress: return 4
        case .acuteDistress:    return 6
        }
    }
}

// MARK: - Ladder Rung

/// A single step (rung) in the mood regulation ladder.
struct LadderRung: Sendable, Equatable, Identifiable {
    let id: UUID
    let targetValence: Double    // 0.0-1.0
    var hrvVerified: Bool        // HRV gate passed at this rung
    var hrvAtRung: Double?       // HRV reading (nil if not yet reached)
    var reachedAt: Date?

    init(id: UUID = UUID(), targetValence: Double, hrvVerified: Bool = false,
         hrvAtRung: Double? = nil, reachedAt: Date? = nil) {
        self.id = id; self.targetValence = targetValence
        self.hrvVerified = hrvVerified; self.hrvAtRung = hrvAtRung; self.reachedAt = reachedAt
    }
}

// MARK: - Ladder Completion Reason

/// Why the mood ladder session ended.
enum LadderCompletionReason: String, Sendable {
    case targetReached  // target valence reached and HRV-verified
    case timeoutElapsed // 15 min elapsed
    case userCancelled  // user manually cancelled
    case inProgress     // still running
}

// MARK: - Mood Ladder Session

/// Tracks the full state of an emotional regulation ladder session.
struct MoodLadderSession: Sendable, Equatable {
    let startState: NegativeStateLevel
    let startValence: Double          // valence at ladder start
    let targetValence: Double         // target (typically 0.5 = neutral)
    var rungs: [LadderRung]
    var currentStep: Int              // 0-based index into rungs
    var tracksPlayed: Int
    var hrvAtEachStep: [Double?]      // parallel to rungs
    var valenceProgression: [Double]  // valence at each track completion
    let startedAt: Date
    var completionReason: LadderCompletionReason

    var isActive: Bool { completionReason == .inProgress }

    var progress: Double {
        guard !rungs.isEmpty else { return 0.0 }
        return Double(currentStep) / Double(rungs.count)
    }

    var elapsed: TimeInterval { Date().timeIntervalSince(startedAt) }

    static func == (lhs: MoodLadderSession, rhs: MoodLadderSession) -> Bool {
        lhs.startState == rhs.startState && lhs.startValence == rhs.startValence
            && lhs.targetValence == rhs.targetValence && lhs.currentStep == rhs.currentStep
            && lhs.tracksPlayed == rhs.tracksPlayed && lhs.completionReason == rhs.completionReason
            && lhs.startedAt == rhs.startedAt
    }
}

// MARK: - Emotional Regulation Engine

/// Detects negative emotional states and manages the ISO-principle mood ladder.
/// Uses composite signal (low HRV + elevated HR + reduced motion + low valence).
/// ISO flow: match -> shift +0.1/track -> HRV gate (>5%) -> hold if no improvement -> complete.
final class EmotionalRegulationEngine {

    private enum Constants {
        static let negativeValenceThreshold: Double = 0.35
        static let neutralValence: Double = 0.50
        static let valenceStepSize: Double = 0.10
        static let hrvImprovementGate: Double = 0.05   // 5% improvement to advance
        static let maxSessionDuration: TimeInterval = 900.0  // 15 min
        static let hrvSuppressionRatio: Double = 0.80
        static let hrElevationBPM: Double = 15.0
        static let reducedMotionThreshold: Double = 0.1
        static let detectionHysteresisCount: Int = 3
        static let cooldownInterval: TimeInterval = 1800.0   // 30 min between ladders
    }

    // MARK: - Thread Safety

    private let lock = NSLock()

    private var _activeSession: MoodLadderSession?
    private var _consecutiveDetections: Int = 0
    private var _lastLadderEndTime: Date?
    private var _lastDetectedLevel: NegativeStateLevel = .neutral

    /// Thread-safe accessors.
    var activeSession: MoodLadderSession? {
        lock.lock(); defer { lock.unlock() }; return _activeSession
    }
    var lastDetectedLevel: NegativeStateLevel {
        lock.lock(); defer { lock.unlock() }; return _lastDetectedLevel
    }
    var isLadderActive: Bool {
        lock.lock(); defer { lock.unlock() }; return _activeSession?.isActive ?? false
    }

    // MARK: - Negative State Detection

    /// Evaluates biometric signals to detect negative emotional states.
    /// Uses 3-sample hysteresis to prevent false triggers.
    func detectNegativeState(
        currentValence: Double,
        currentHRV: Double,
        baselineHRV: Double,
        currentHR: Double,
        restingHR: Double,
        movementMagnitude: Double?
    ) -> NegativeStateLevel {
        // Composite negative signal scoring
        var negativeScore: Double = 0.0

        // Low valence signal (strongest indicator)
        if currentValence < Constants.negativeValenceThreshold {
            negativeScore += (Constants.negativeValenceThreshold - currentValence) * 3.0
        }

        // HRV suppression relative to personal baseline
        let hrvRatio = baselineHRV > 0 ? currentHRV / baselineHRV : 1.0
        if hrvRatio < Constants.hrvSuppressionRatio {
            negativeScore += (Constants.hrvSuppressionRatio - hrvRatio) * 2.0
        }

        // HR elevation above resting
        let hrElevation = currentHR - restingHR
        if hrElevation > Constants.hrElevationBPM {
            negativeScore += min(1.0, (hrElevation - Constants.hrElevationBPM) / 20.0)
        }

        // Reduced motion (withdrawal signal)
        if let motion = movementMagnitude, motion < Constants.reducedMotionThreshold {
            negativeScore += 0.3
        }

        // Map composite score to severity level
        let rawLevel: NegativeStateLevel
        if negativeScore >= 1.5 {
            rawLevel = .acuteDistress
        } else if negativeScore >= 0.8 {
            rawLevel = .moderateDistress
        } else if negativeScore >= 0.3 {
            rawLevel = .mildDistress
        } else {
            rawLevel = .neutral
        }

        // Apply hysteresis: require consecutive agreeing detections
        return applyDetectionHysteresis(rawLevel)
    }

    /// Hysteresis: requires consecutive agreeing readings (mirrors MusicNeedInference).
    private func applyDetectionHysteresis(_ rawLevel: NegativeStateLevel) -> NegativeStateLevel {
        lock.lock()
        defer { lock.unlock() }

        if rawLevel == .neutral {
            _consecutiveDetections = 0
            _lastDetectedLevel = .neutral
            return .neutral
        }

        if rawLevel == _lastDetectedLevel {
            _consecutiveDetections += 1
        } else {
            _consecutiveDetections = 1
            _lastDetectedLevel = rawLevel
        }

        if _consecutiveDetections >= Constants.detectionHysteresisCount {
            return rawLevel
        }

        // Not enough consecutive detections yet
        return .neutral
    }

    // MARK: - Ladder Session Management

    /// Initiates a new mood ladder session. Returns nil if already active or on cooldown.
    @discardableResult
    func startLadder(
        level: NegativeStateLevel,
        currentValence: Double
    ) -> MoodLadderSession? {
        lock.lock()
        defer { lock.unlock() }

        guard level != .neutral else { return nil }

        // Don't start if already running
        guard _activeSession == nil || _activeSession?.isActive == false else {
            logDebug(
                "EmotionalRegulationEngine: ladder already active, ignoring start request",
                category: .stateEngine
            )
            return nil
        }

        // Cooldown check
        if let lastEnd = _lastLadderEndTime,
           Date().timeIntervalSince(lastEnd) < Constants.cooldownInterval {
            logDebug(
                "EmotionalRegulationEngine: cooldown active, ignoring start request",
                category: .stateEngine
            )
            return nil
        }

        // Build rungs from current valence to target
        let targetValence = Constants.neutralValence
        let clampedStart = min(max(currentValence, 0.0), 1.0)
        var rungs: [LadderRung] = []
        var stepValence = clampedStart

        // First rung: match current valence (ISO principle match phase)
        rungs.append(LadderRung(targetValence: stepValence))

        // Subsequent rungs: shift by +0.1 per step until target
        while stepValence + Constants.valenceStepSize <= targetValence {
            stepValence += Constants.valenceStepSize
            rungs.append(LadderRung(targetValence: min(stepValence, targetValence)))
        }

        // Final rung at exact target if not already there
        if let lastRung = rungs.last, lastRung.targetValence < targetValence {
            rungs.append(LadderRung(targetValence: targetValence))
        }

        let session = MoodLadderSession(
            startState: level,
            startValence: clampedStart,
            targetValence: targetValence,
            rungs: rungs,
            currentStep: 0,
            tracksPlayed: 0,
            hrvAtEachStep: Array(repeating: nil, count: rungs.count),
            valenceProgression: [clampedStart],
            startedAt: Date(),
            completionReason: .inProgress
        )

        _activeSession = session

        logInfo(
            "EmotionalRegulationEngine: ladder started "
            + "(level=\(level.displayName), startValence=\(String(format: "%.2f", clampedStart)), "
            + "rungs=\(rungs.count))",
            category: .stateEngine
        )

        return session
    }

    /// Records a track completion and evaluates HRV gate for advancement.
    /// Advance if HRV >= 5% better; hold if not; complete on target/timeout.
    @discardableResult
    func recordTrackCompletion(
        currentHRV: Double,
        currentValence: Double
    ) -> MoodLadderSession? {
        lock.lock()
        defer { lock.unlock() }

        guard var session = _activeSession, session.isActive else { return nil }

        session.tracksPlayed += 1
        session.valenceProgression.append(currentValence)

        // Record HRV at current step
        if session.currentStep < session.hrvAtEachStep.count {
            session.hrvAtEachStep[session.currentStep] = currentHRV
        }

        // Check timeout
        if session.elapsed >= Constants.maxSessionDuration {
            session.completionReason = .timeoutElapsed
            _activeSession = session
            _lastLadderEndTime = Date()
            logInfo(
                "EmotionalRegulationEngine: ladder completed (timeout, "
                + "tracks=\(session.tracksPlayed))",
                category: .stateEngine
            )
            return session
        }

        // HRV verification gate
        let previousHRV = previousStepHRV(in: session)
        let hrvImproved: Bool

        if let prev = previousHRV, prev > 0 {
            let improvementRatio = (currentHRV - prev) / prev
            hrvImproved = improvementRatio >= Constants.hrvImprovementGate
        } else {
            // No previous HRV data; allow advancement on first track
            hrvImproved = true
        }

        if hrvImproved {
            // Mark current rung as HRV-verified
            if session.currentStep < session.rungs.count {
                session.rungs[session.currentStep].hrvVerified = true
                session.rungs[session.currentStep].hrvAtRung = currentHRV
                session.rungs[session.currentStep].reachedAt = Date()
            }

            // Advance to next rung
            let nextStep = session.currentStep + 1
            if nextStep >= session.rungs.count {
                // Ladder complete -- target reached
                session.completionReason = .targetReached
                _activeSession = session
                _lastLadderEndTime = Date()
                logInfo(
                    "EmotionalRegulationEngine: ladder completed (target reached, "
                    + "tracks=\(session.tracksPlayed))",
                    category: .stateEngine
                )
                return session
            }

            session.currentStep = nextStep
            logDebug(
                "EmotionalRegulationEngine: advanced to rung \(nextStep)/\(session.rungs.count) "
                + "(HRV improved by \(String(format: "%.1f", hrvImprovementPercentage(previous: previousHRV, current: currentHRV)))%)",
                category: .stateEngine
            )
        } else {
            // HRV did not improve -- hold at current rung
            logDebug(
                "EmotionalRegulationEngine: holding at rung \(session.currentStep)/\(session.rungs.count) "
                + "(HRV did not improve)",
                category: .stateEngine
            )
        }

        _activeSession = session
        return session
    }

    /// Target valence for current rung (used by music selection).
    func currentTargetValence() -> Double? {
        lock.lock()
        defer { lock.unlock() }

        guard let session = _activeSession, session.isActive else { return nil }
        guard session.currentStep < session.rungs.count else { return nil }
        return session.rungs[session.currentStep].targetValence
    }

    /// Cancels the active ladder session.
    func cancelLadder() {
        lock.lock()
        defer { lock.unlock() }

        guard _activeSession != nil else { return }
        _activeSession?.completionReason = .userCancelled
        _lastLadderEndTime = Date()

        logInfo("EmotionalRegulationEngine: ladder cancelled by user", category: .stateEngine)
    }

    /// Resets all detection and session state.
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        _activeSession = nil
        _consecutiveDetections = 0
        _lastLadderEndTime = nil
        _lastDetectedLevel = .neutral

        logInfo("EmotionalRegulationEngine: state reset", category: .stateEngine)
    }

    // MARK: - Private Helpers

    private func previousStepHRV(in session: MoodLadderSession) -> Double? {
        let prevIndex = session.currentStep - 1
        guard prevIndex >= 0, prevIndex < session.hrvAtEachStep.count else { return nil }
        return session.hrvAtEachStep[prevIndex]
    }

    private func hrvImprovementPercentage(previous: Double?, current: Double) -> Double {
        guard let prev = previous, prev > 0 else { return 0.0 }
        return ((current - prev) / prev) * 100.0
    }
}

#endif
