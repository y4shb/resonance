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

    public var displayName: String {
        switch self {
        case .workoutBuildPeakCool: return "Workout"
        case .relaxationDescend: return "Relaxation"
        case .focusSustainPlateau: return "Focus"
        case .sleepWindDown: return "Sleep"
        case .morningRise: return "Morning"
        case .commuteEnergize: return "Commute"
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
        case .sleepWindDown:         return generateSleepPhases(currentState: currentState, scale: scale)
        case .focusSustainPlateau:   return generateFocusPhases(currentState: currentState, scale: scale)
        case .relaxationDescend:     return generateRelaxationPhases(currentState: currentState, scale: scale)
        case .morningRise:           return generateMorningPhases(scale: scale)
        case .commuteEnergize:       return generateCommutePhases(currentState: currentState, scale: scale)
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

    // MARK: - Sleep: decreasing 80->60 at -3 to -5 BPM/song, all instrumental

    private func generateSleepPhases(currentState: StateVector, scale: Double) -> [ArcPhase] {
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
