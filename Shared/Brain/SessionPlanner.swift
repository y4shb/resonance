//
//  SessionPlanner.swift
//  Resonance
//
//  Plans multi-song session arcs using research-backed BPM ranges.
//  Implements the iso-principle at session level: match -> shift -> arrive -> sustain.
//

import Foundation

// MARK: - Session Phase

/// The four stages of a session arc (iso-principle at session level).
public enum SessionPhase: String, Codable, CaseIterable, Sendable {
    case match   // Match user's current biometric state
    case shift   // Gradually move toward the therapeutic target
    case arrive  // Reach the target zone
    case sustain // Hold the target state for the remainder
}

// MARK: - Arc Phase

/// A single phase within a session arc with target BPM/energy ranges.
public struct ArcPhase: Codable, Sendable, Equatable {
    public let phase: SessionPhase
    public let targetBPMRange: ClosedRange<Double>
    public let targetEnergyRange: ClosedRange<Double>
    public let songCount: Int
    public let preferInstrumental: Bool
    /// BPM change per song (signed). Zero = hold steady.
    public let bpmDeltaPerSong: Double

    public var targetBPM: Double {
        (targetBPMRange.lowerBound + targetBPMRange.upperBound) / 2.0
    }

    public var targetEnergy: Double {
        (targetEnergyRange.lowerBound + targetEnergyRange.upperBound) / 2.0
    }

    public init(
        phase: SessionPhase,
        targetBPMRange: ClosedRange<Double>,
        targetEnergyRange: ClosedRange<Double>,
        songCount: Int,
        preferInstrumental: Bool = false,
        bpmDeltaPerSong: Double = 0.0
    ) {
        self.phase = phase
        self.targetBPMRange = targetBPMRange
        self.targetEnergyRange = targetEnergyRange
        self.songCount = songCount
        self.preferInstrumental = preferInstrumental
        self.bpmDeltaPerSong = bpmDeltaPerSong
    }
}

// MARK: - Session Arc

/// A planned sequence of ArcPhases forming the full session trajectory.
public struct SessionArc: Codable, Sendable {
    public let phases: [ArcPhase]
    public let template: ArcTemplate
    public let createdAt: Date

    public var totalSongs: Int {
        phases.reduce(0) { $0 + $1.songCount }
    }

    public init(phases: [ArcPhase], template: ArcTemplate, createdAt: Date = Date()) {
        self.phases = phases
        self.template = template
        self.createdAt = createdAt
    }
}

// MARK: - Arc Template

/// Predefined arc shapes for common listening scenarios.
public enum ArcTemplate: String, Codable, CaseIterable, Sendable {
    case workoutBuildPeakCool   // warm-up -> build -> peak -> cool -> recovery
    case relaxationDescend      // match -> -5 BPM/song -> sustain 70-90
    case focusSustainPlateau    // match -> +5 BPM -> sustain 70-110 instrumental
    case sleepWindDown          // decreasing 80->60 at -3 to -5 BPM/song
    case morningRise            // gentle ramp 70 -> 110-120
    case commuteEnergize        // quick energize to 100-130
    case adhdPomodoro           // 25-min focus blocks + 5-min breaks
    case recoveryArc            // BPM decreasing toward resting HR, high valence
    case emotionalLadder        // valence increases from detected negative level with HRV gates
    case commuteDecompress      // evening commute: decreasing energy from work-stress to calm

    public var displayName: String {
        switch self {
        case .workoutBuildPeakCool: return "Workout"
        case .relaxationDescend: return "Relaxation"
        case .focusSustainPlateau: return "Focus"
        case .sleepWindDown: return "Sleep"
        case .morningRise: return "Morning"
        case .commuteEnergize: return "Commute"
        case .adhdPomodoro: return "ADHD Focus"
        case .recoveryArc: return "Recovery"
        case .emotionalLadder: return "Mood Lift"
        case .commuteDecompress: return "Decompress"
        }
    }
}

// MARK: - SessionPlanner

/// Plans session-level song arcs using research-backed BPM ranges.
///
/// Research-backed BPM ranges:
/// - Workout: 100-170 BPM (varies by phase)
/// - Sleep:   60-80 BPM (decreasing trajectory)
/// - Focus:   70-110 BPM (steady, instrumental preferred)
public struct SessionPlanner: Sendable {

    public init() {}

    // MARK: - Public API

    /// Plans a session arc based on current state and target context.
    public func planSession(
        currentState: StateVector,
        targetContext: ActivityContext,
        estimatedDuration: TimeInterval = 30
    ) -> SessionArc {
        let template = selectTemplate(for: targetContext)
        let phases = generatePhases(
            template: template,
            currentState: currentState,
            estimatedDuration: estimatedDuration
        )
        logInfo(
            "SessionPlanner: planned \(template.rawValue) arc, "
            + "\(phases.count) phases, ~\(phases.reduce(0) { $0 + $1.songCount }) songs",
            category: .decisionEngine
        )
        return SessionArc(phases: phases, template: template)
    }

    /// Returns the current ArcPhase for the given number of songs played.
    /// Returns the last phase if songsPlayed exceeds all phases.
    public func currentPhase(for arc: SessionArc, songsPlayed: Int) -> ArcPhase {
        var consumed = 0
        for phase in arc.phases {
            consumed += phase.songCount
            if songsPlayed < consumed { return phase }
        }
        return arc.phases.last ?? defaultSustainPhase()
    }

    // MARK: - Template Selection

    private func selectTemplate(for context: ActivityContext) -> ArcTemplate {
        switch context {
        case .workout:              return .workoutBuildPeakCool
        case .preSleep:             return .sleepWindDown
        case .deepWork, .work:      return .focusSustainPlateau
        case .relaxation, .postWorkout: return .relaxationDescend
        case .morning:              return .morningRise
        case .commute:              return .commuteEnergize
        case .social, .unknown:     return .relaxationDescend
        }
    }

    // MARK: - Phase Generation

    private func generatePhases(
        template: ArcTemplate,
        currentState: StateVector,
        estimatedDuration: TimeInterval
    ) -> [ArcPhase] {
        let estimatedTotalSongs = max(4, Int(estimatedDuration / 3.5))
        let scale = Double(estimatedTotalSongs) / 15.0

        switch template {
        case .workoutBuildPeakCool:  return generateWorkoutPhases(scale: scale)
        case .sleepWindDown:         return generateSleepWindDownPhases(currentState: currentState, scale: scale)
        case .focusSustainPlateau:   return generateFocusPhases(currentState: currentState, scale: scale)
        case .relaxationDescend:     return generateRelaxationPhases(currentState: currentState, scale: scale)
        case .morningRise:           return generateMorningPhases(scale: scale)
        case .commuteEnergize:       return generateCommutePhases(currentState: currentState, scale: scale)
        case .adhdPomodoro:          return generateADHDPomodoroPhases(scale: scale)
        case .recoveryArc:           return generateRecoveryPhases(currentState: currentState, scale: scale)
        case .emotionalLadder:       return generateEmotionalLadderPhases(currentState: currentState, scale: scale)
        case .commuteDecompress:     return generateCommuteDecompressPhases(currentState: currentState, scale: scale)
        }
    }

    // MARK: - Workout: warm-up(100-115) -> build(130-150) -> peak(140-170) -> cool(80-100) -> recovery(60-80)

    private func generateWorkoutPhases(scale: Double) -> [ArcPhase] {
        [
            ArcPhase(phase: .match, targetBPMRange: 100...115,
                     targetEnergyRange: 0.4...0.6, songCount: scaled(2, by: scale), bpmDeltaPerSong: 5.0),
            ArcPhase(phase: .shift, targetBPMRange: 130...150,
                     targetEnergyRange: 0.6...0.8, songCount: scaled(3, by: scale), bpmDeltaPerSong: 8.0),
            ArcPhase(phase: .arrive, targetBPMRange: 140...170,
                     targetEnergyRange: 0.8...1.0, songCount: scaled(5, by: scale)),
            ArcPhase(phase: .shift, targetBPMRange: 80...100,
                     targetEnergyRange: 0.3...0.5, songCount: scaled(3, by: scale), bpmDeltaPerSong: -10.0),
            ArcPhase(phase: .sustain, targetBPMRange: 60...80,
                     targetEnergyRange: 0.1...0.3, songCount: scaled(2, by: scale))
        ]
    }

    // MARK: - Sleep Wind-Down: gradual energy decrease from current to near-zero
    // BPM 60-75, high familiarity, over user's average sleep onset latency

    private func generateSleepWindDownPhases(currentState: StateVector, scale: Double) -> [ArcPhase] {
        let startBPM = min(80.0, max(60.0, currentState.energy * 100.0 + 30.0))
        return [
            ArcPhase(phase: .match, targetBPMRange: (startBPM - 2)...(startBPM + 2),
                     targetEnergyRange: 0.2...0.4, songCount: scaled(2, by: scale), preferInstrumental: true),
            ArcPhase(phase: .shift, targetBPMRange: 70...75,
                     targetEnergyRange: 0.15...0.3, songCount: scaled(3, by: scale),
                     preferInstrumental: true, bpmDeltaPerSong: -3.0),
            ArcPhase(phase: .shift, targetBPMRange: 65...70,
                     targetEnergyRange: 0.1...0.2, songCount: scaled(3, by: scale),
                     preferInstrumental: true, bpmDeltaPerSong: -3.0),
            ArcPhase(phase: .arrive, targetBPMRange: 60...65,
                     targetEnergyRange: 0.05...0.15, songCount: scaled(3, by: scale),
                     preferInstrumental: true, bpmDeltaPerSong: -2.0),
            ArcPhase(phase: .sustain, targetBPMRange: 60...65,
                     targetEnergyRange: 0.0...0.1, songCount: scaled(4, by: scale), preferInstrumental: true)
        ]
    }

    // MARK: - Focus: match -> +5 BPM -> sustain 70-110 instrumental

    private func generateFocusPhases(currentState: StateVector, scale: Double) -> [ArcPhase] {
        let currentBPM = estimateBPMFromEnergy(currentState.energy)
        let matchBPM = clamp(currentBPM, 70, 110)
        return [
            ArcPhase(phase: .match, targetBPMRange: (matchBPM - 5)...(matchBPM + 5),
                     targetEnergyRange: 0.3...0.5, songCount: scaled(2, by: scale), preferInstrumental: true),
            ArcPhase(phase: .shift, targetBPMRange: matchBPM...(matchBPM + 10),
                     targetEnergyRange: 0.3...0.5, songCount: scaled(2, by: scale),
                     preferInstrumental: true, bpmDeltaPerSong: 5.0),
            ArcPhase(phase: .sustain, targetBPMRange: 70...110,
                     targetEnergyRange: 0.3...0.5, songCount: scaled(11, by: scale), preferInstrumental: true)
        ]
    }

    // MARK: - Relaxation: match -> -5 BPM/song -> sustain 70-90

    private func generateRelaxationPhases(currentState: StateVector, scale: Double) -> [ArcPhase] {
        let currentBPM = estimateBPMFromEnergy(currentState.energy)
        return [
            ArcPhase(phase: .match, targetBPMRange: (currentBPM - 5)...(currentBPM + 5),
                     targetEnergyRange: 0.3...0.5, songCount: scaled(2, by: scale)),
            ArcPhase(phase: .shift, targetBPMRange: 85...100,
                     targetEnergyRange: 0.2...0.4, songCount: scaled(4, by: scale), bpmDeltaPerSong: -5.0),
            ArcPhase(phase: .arrive, targetBPMRange: 70...90,
                     targetEnergyRange: 0.15...0.3, songCount: scaled(3, by: scale)),
            ArcPhase(phase: .sustain, targetBPMRange: 70...90,
                     targetEnergyRange: 0.1...0.25, songCount: scaled(6, by: scale))
        ]
    }

    // MARK: - Morning: gentle ramp 70 -> 110-120

    private func generateMorningPhases(scale: Double) -> [ArcPhase] {
        [
            ArcPhase(phase: .match, targetBPMRange: 70...85,
                     targetEnergyRange: 0.2...0.4, songCount: scaled(3, by: scale)),
            ArcPhase(phase: .shift, targetBPMRange: 90...105,
                     targetEnergyRange: 0.4...0.6, songCount: scaled(4, by: scale), bpmDeltaPerSong: 5.0),
            ArcPhase(phase: .arrive, targetBPMRange: 105...120,
                     targetEnergyRange: 0.5...0.7, songCount: scaled(3, by: scale)),
            ArcPhase(phase: .sustain, targetBPMRange: 100...120,
                     targetEnergyRange: 0.5...0.7, songCount: scaled(5, by: scale))
        ]
    }

    // MARK: - Commute: quick energize to 100-130 BPM

    private func generateCommutePhases(currentState: StateVector, scale: Double) -> [ArcPhase] {
        let currentBPM = estimateBPMFromEnergy(currentState.energy)
        return [
            ArcPhase(phase: .match, targetBPMRange: (currentBPM - 5)...(currentBPM + 5),
                     targetEnergyRange: 0.3...0.5, songCount: scaled(1, by: scale)),
            ArcPhase(phase: .shift, targetBPMRange: 100...115,
                     targetEnergyRange: 0.5...0.7, songCount: scaled(3, by: scale), bpmDeltaPerSong: 8.0),
            ArcPhase(phase: .sustain, targetBPMRange: 100...130,
                     targetEnergyRange: 0.5...0.7, songCount: scaled(11, by: scale))
        ]
    }

    // MARK: - ADHD Pomodoro: 25-min focus blocks (instrumental, BPM 80-105, energy 0.3-0.5)
    //                        + 5-min breaks (relaxed, allows vocals, higher energy)

    private func generateADHDPomodoroPhases(scale: Double) -> [ArcPhase] {
        // Each focus block ~7 songs (25 min / 3.5 min avg), break ~1-2 songs (5 min)
        let focusSongs = scaled(7, by: scale)
        let breakSongs = scaled(2, by: scale)

        return [
            // Focus block 1
            ArcPhase(phase: .match, targetBPMRange: 80...95,
                     targetEnergyRange: 0.3...0.5, songCount: scaled(2, by: scale),
                     preferInstrumental: true, bpmDeltaPerSong: 3.0),
            ArcPhase(phase: .sustain, targetBPMRange: 85...105,
                     targetEnergyRange: 0.3...0.5, songCount: focusSongs,
                     preferInstrumental: true),
            // Break 1
            ArcPhase(phase: .shift, targetBPMRange: 90...115,
                     targetEnergyRange: 0.4...0.65, songCount: breakSongs),
            // Focus block 2
            ArcPhase(phase: .shift, targetBPMRange: 80...95,
                     targetEnergyRange: 0.3...0.5, songCount: scaled(1, by: scale),
                     preferInstrumental: true, bpmDeltaPerSong: -5.0),
            ArcPhase(phase: .sustain, targetBPMRange: 85...105,
                     targetEnergyRange: 0.3...0.5, songCount: focusSongs,
                     preferInstrumental: true),
            // Break 2
            ArcPhase(phase: .shift, targetBPMRange: 90...115,
                     targetEnergyRange: 0.4...0.65, songCount: breakSongs)
        ]
    }

    // MARK: - Recovery: BPM decreasing by 5/track toward resting HR, high valence, low energy

    private func generateRecoveryPhases(currentState: StateVector, scale: Double) -> [ArcPhase] {
        // Start from elevated post-workout state, descend toward resting
        let startBPM = estimateBPMFromEnergy(currentState.energy)
        let targetRestBPM = max(60.0, startBPM - 40.0) // approximate resting HR zone
        let stepsNeeded = max(3, Int((startBPM - targetRestBPM) / 5.0))

        let midBPM = (startBPM + targetRestBPM) / 2.0
        return [
            ArcPhase(phase: .match, targetBPMRange: (startBPM - 5)...(startBPM + 5),
                     targetEnergyRange: 0.3...0.5, songCount: scaled(2, by: scale),
                     bpmDeltaPerSong: -5.0),
            ArcPhase(phase: .shift, targetBPMRange: (midBPM - 5)...(midBPM + 5),
                     targetEnergyRange: 0.2...0.4, songCount: scaled(min(stepsNeeded, 5), by: scale),
                     bpmDeltaPerSong: -5.0),
            ArcPhase(phase: .arrive, targetBPMRange: (targetRestBPM - 5)...(targetRestBPM + 5),
                     targetEnergyRange: 0.1...0.3, songCount: scaled(2, by: scale)),
            ArcPhase(phase: .sustain, targetBPMRange: (targetRestBPM - 5)...(targetRestBPM + 10),
                     targetEnergyRange: 0.1...0.25, songCount: scaled(4, by: scale))
        ]
    }

    // MARK: - Emotional Ladder: valence starts at detected negative level,
    //   increases by ~0.1/track with HRV gates. Energy stays moderate.

    private func generateEmotionalLadderPhases(currentState: StateVector, scale: Double) -> [ArcPhase] {
        // Start at the user's current (negative) valence, climb gradually
        let startValence = currentState.valence
        let startEnergy = clamp(currentState.energy, 0.2, 0.5)
        let startBPM = estimateBPMFromEnergy(startEnergy)

        // Each step climbs ~0.1 valence; we map valence improvement to slight energy increase
        let step1Energy = clamp(startEnergy + 0.05, 0.0, 1.0)
        let step2Energy = clamp(startEnergy + 0.1, 0.0, 1.0)
        let targetEnergy = clamp(startEnergy + 0.15, 0.0, 1.0)

        let step1BPM = estimateBPMFromEnergy(step1Energy)
        let step2BPM = estimateBPMFromEnergy(step2Energy)
        let targetBPM = estimateBPMFromEnergy(targetEnergy)

        return [
            // Match: meet user at current emotional state
            ArcPhase(phase: .match, targetBPMRange: (startBPM - 5)...(startBPM + 5),
                     targetEnergyRange: clamp(startEnergy - 0.05, 0, 1)...clamp(startEnergy + 0.05, 0, 1),
                     songCount: scaled(2, by: scale)),
            // Shift 1: first valence rung (+0.1-0.2 valence, slight energy lift)
            ArcPhase(phase: .shift, targetBPMRange: (step1BPM - 5)...(step1BPM + 10),
                     targetEnergyRange: clamp(step1Energy - 0.05, 0, 1)...clamp(step1Energy + 0.1, 0, 1),
                     songCount: scaled(3, by: scale), bpmDeltaPerSong: 2.0),
            // Shift 2: second valence rung (+0.2-0.3 valence, moderate energy)
            ArcPhase(phase: .shift, targetBPMRange: (step2BPM - 5)...(step2BPM + 10),
                     targetEnergyRange: clamp(step2Energy - 0.05, 0, 1)...clamp(step2Energy + 0.1, 0, 1),
                     songCount: scaled(3, by: scale), bpmDeltaPerSong: 2.0),
            // Arrive: reach positive valence zone
            ArcPhase(phase: .arrive, targetBPMRange: (targetBPM - 5)...(targetBPM + 10),
                     targetEnergyRange: clamp(targetEnergy - 0.05, 0, 1)...clamp(targetEnergy + 0.1, 0, 1),
                     songCount: scaled(2, by: scale)),
            // Sustain: hold positive state
            ArcPhase(phase: .sustain, targetBPMRange: (targetBPM - 10)...(targetBPM + 10),
                     targetEnergyRange: clamp(targetEnergy - 0.1, 0, 1)...clamp(targetEnergy + 0.1, 0, 1),
                     songCount: scaled(5, by: scale))
        ]
    }

    // MARK: - Commute Decompress: evening commute, decreasing energy from work-stress to calm

    private func generateCommuteDecompressPhases(currentState: StateVector, scale: Double) -> [ArcPhase] {
        // Start at work-stress energy level, descend to calm
        let startEnergy = clamp(currentState.energy, 0.4, 0.8)
        let startBPM = estimateBPMFromEnergy(startEnergy)
        let midBPM = estimateBPMFromEnergy(0.35)
        let targetBPM = estimateBPMFromEnergy(0.2)

        return [
            // Match: meet user at current work-stress level
            ArcPhase(phase: .match, targetBPMRange: (startBPM - 5)...(startBPM + 5),
                     targetEnergyRange: clamp(startEnergy - 0.05, 0, 1)...clamp(startEnergy + 0.05, 0, 1),
                     songCount: scaled(2, by: scale)),
            // Shift: gradually decrease energy and BPM
            ArcPhase(phase: .shift, targetBPMRange: (midBPM - 5)...(midBPM + 10),
                     targetEnergyRange: 0.25...0.4, songCount: scaled(4, by: scale),
                     bpmDeltaPerSong: -5.0),
            // Arrive: reach calm state
            ArcPhase(phase: .arrive, targetBPMRange: (targetBPM - 5)...(targetBPM + 10),
                     targetEnergyRange: 0.15...0.3, songCount: scaled(3, by: scale)),
            // Sustain: hold calm for remainder of commute
            ArcPhase(phase: .sustain, targetBPMRange: 70...90,
                     targetEnergyRange: 0.1...0.25, songCount: scaled(6, by: scale))
        ]
    }

    // MARK: - DJ Energy Level Abstraction

    /// Maps 0.0-1.0 energy to 1-10 DJ scale for user-facing display.
    public static func djEnergyLevel(from energy: Double) -> Int {
        let clamped = min(1.0, max(0.0, energy))
        return max(1, min(10, Int((clamped * 9.0) + 1.0)))
    }

    /// Returns a description string for a DJ energy level (1-10).
    public static func djEnergyDescription(level: Int) -> String {
        switch level {
        case 1...2: return "Very Calm"
        case 3...4: return "Relaxed"
        case 5...6: return "Moderate"
        case 7...8: return "Energetic"
        case 9...10: return "Peak Energy"
        default: return "Moderate"
        }
    }

    // MARK: - Trajectory Arc (Mood Journey)

    /// Plans a session arc that transitions from the user's current mood
    /// to their target mood using the iso-principle:
    ///   Phase 1 (Match):   1-2 songs matching the current state.
    ///   Phase 2 (Shift):   2-3 songs shifting by max 0.15 energy and 0.2 valence per song.
    ///   Phase 3 (Arrive):  1 song reaching the target.
    ///   Phase 4 (Sustain): Hold at target.
    public func planTrajectoryArc(trajectory: MoodTrajectory) -> SessionArc {
        let currentBPM = estimateBPMFromEnergy(trajectory.currentEnergy)
        let targetBPM = estimateBPMFromEnergy(trajectory.targetEnergy)

        // Phase 1: Match -- meet the user where they are
        let matchBPMLow = clamp(currentBPM - 5, 50, 200)
        let matchBPMHigh = clamp(currentBPM + 5, 50, 200)
        let matchEnergyLow = clamp(trajectory.currentEnergy - 0.05, 0, 1)
        let matchEnergyHigh = clamp(trajectory.currentEnergy + 0.05, 0, 1)
        let matchPhase = ArcPhase(
            phase: .match,
            targetBPMRange: matchBPMLow...matchBPMHigh,
            targetEnergyRange: matchEnergyLow...matchEnergyHigh,
            songCount: trajectory.gapMagnitude > 0.3 ? 2 : 1
        )

        // Phase 2: Shift -- gradually move toward target
        // Max shift per song: 0.15 energy, 0.2 valence
        let energyDelta = trajectory.targetEnergy - trajectory.currentEnergy
        let maxEnergyShiftPerSong = 0.15
        let shiftSongCount: Int = {
            guard abs(energyDelta) > 0.05 else { return 2 }
            let needed = Int(ceil(abs(energyDelta) / maxEnergyShiftPerSong))
            return min(max(needed, 2), 3)
        }()

        let midEnergy = trajectory.currentEnergy + energyDelta * 0.5
        let midBPM = estimateBPMFromEnergy(midEnergy)
        let bpmDelta: Double = {
            guard shiftSongCount > 0 else { return 0.0 }
            return (targetBPM - currentBPM) / Double(shiftSongCount)
        }()

        let shiftBPMLow = clamp(min(currentBPM, targetBPM) - 5, 50, 200)
        let shiftBPMHigh = clamp(max(midBPM, targetBPM) + 5, 50, 200)
        let shiftEnergyLow = clamp(min(trajectory.currentEnergy, trajectory.targetEnergy), 0, 1)
        let shiftEnergyHigh = clamp(max(midEnergy, trajectory.targetEnergy), 0, 1)
        let shiftPhase = ArcPhase(
            phase: .shift,
            targetBPMRange: shiftBPMLow...shiftBPMHigh,
            targetEnergyRange: shiftEnergyLow...shiftEnergyHigh,
            songCount: shiftSongCount,
            bpmDeltaPerSong: bpmDelta
        )

        // Phase 3: Arrive -- land on the target
        let arriveBPMLow = clamp(targetBPM - 5, 50, 200)
        let arriveBPMHigh = clamp(targetBPM + 5, 50, 200)
        let arriveEnergyLow = clamp(trajectory.targetEnergy - 0.05, 0, 1)
        let arriveEnergyHigh = clamp(trajectory.targetEnergy + 0.05, 0, 1)
        let arrivePhase = ArcPhase(
            phase: .arrive,
            targetBPMRange: arriveBPMLow...arriveBPMHigh,
            targetEnergyRange: arriveEnergyLow...arriveEnergyHigh,
            songCount: 1
        )

        // Phase 4: Sustain -- hold at target
        let sustainBPMLow = clamp(targetBPM - 10, 50, 200)
        let sustainBPMHigh = clamp(targetBPM + 10, 50, 200)
        let sustainEnergyLow = clamp(trajectory.targetEnergy - 0.1, 0, 1)
        let sustainEnergyHigh = clamp(trajectory.targetEnergy + 0.1, 0, 1)
        let sustainPhase = ArcPhase(
            phase: .sustain,
            targetBPMRange: sustainBPMLow...sustainBPMHigh,
            targetEnergyRange: sustainEnergyLow...sustainEnergyHigh,
            songCount: 4
        )

        let phases = [matchPhase, shiftPhase, arrivePhase, sustainPhase]
        logInfo(
            "SessionPlanner: planned trajectory arc, "
            + "\(phases.count) phases, ~\(phases.reduce(0) { $0 + $1.songCount }) songs, "
            + "gap=\(String(format: "%.2f", trajectory.gapMagnitude))",
            category: .decisionEngine
        )
        return SessionArc(phases: phases, template: .relaxationDescend)
    }

    // MARK: - Helpers

    private func estimateBPMFromEnergy(_ energy: Double) -> Double { 60.0 + energy * 100.0 }

    private func scaled(_ base: Int, by scale: Double) -> Int {
        max(1, Int(round(Double(base) * scale)))
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private func defaultSustainPhase() -> ArcPhase {
        ArcPhase(phase: .sustain, targetBPMRange: 80...110, targetEnergyRange: 0.3...0.5, songCount: 10)
    }
}

// MARK: - SessionArc Extensions

extension SessionArc {
    /// Returns the energy trajectory as (songIndex, energy) pairs for visualization.
    public var energyTrajectory: [(songIndex: Int, energy: Double)] {
        var trajectory: [(Int, Double)] = []
        var songIndex = 0
        for phase in phases {
            for i in 0..<phase.songCount {
                let progress = phase.songCount > 1 ? Double(i) / Double(phase.songCount - 1) : 0.5
                let energy = phase.targetEnergyRange.lowerBound
                    + progress * (phase.targetEnergyRange.upperBound - phase.targetEnergyRange.lowerBound)
                trajectory.append((songIndex, energy))
                songIndex += 1
            }
        }
        return trajectory
    }

    /// Returns the DJ energy level (1-10) for a given song index.
    public func djEnergyLevel(at songIndex: Int) -> Int {
        let trajectory = energyTrajectory
        guard let entry = trajectory.first(where: { $0.songIndex >= songIndex })
            ?? trajectory.last else { return 5 }
        return SessionPlanner.djEnergyLevel(from: entry.energy)
    }
}
