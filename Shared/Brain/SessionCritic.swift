//
//  SessionCritic.swift
//  Resonance
//
//  Evaluates how well actual session energy matched the planned arc.
//  Produces the R_session (arc adherence) component of the multi-component
//  delayed reward signal. Used by the learning subsystem to evaluate
//  whether the DJ followed through on its plan.
//

import Foundation

// MARK: - Arc Adherence Result

/// The result of evaluating a session against its planned arc.
/// Contains the R_session reward component and detailed per-phase scores.
public struct ArcAdherenceResult: Codable, Sendable {
    /// Overall arc adherence score (0.0-1.0).
    /// 1.0 = actual energy perfectly matched the planned arc.
    /// 0.0 = complete divergence from the plan.
    public let overallScore: Double

    /// Per-phase adherence scores.
    public let phaseScores: [PhaseAdherenceScore]

    /// The planned template that was evaluated against.
    public let template: ArcTemplate

    /// Number of songs in the session.
    public let totalSongsPlayed: Int

    /// Average deviation from planned energy trajectory.
    public let avgEnergyDeviation: Double

    /// Average deviation from planned BPM trajectory.
    public let avgBPMDeviation: Double

    public init(
        overallScore: Double,
        phaseScores: [PhaseAdherenceScore],
        template: ArcTemplate,
        totalSongsPlayed: Int,
        avgEnergyDeviation: Double,
        avgBPMDeviation: Double
    ) {
        self.overallScore = overallScore
        self.phaseScores = phaseScores
        self.template = template
        self.totalSongsPlayed = totalSongsPlayed
        self.avgEnergyDeviation = avgEnergyDeviation
        self.avgBPMDeviation = avgBPMDeviation
    }
}

// MARK: - Phase Adherence Score

/// How well a single phase of the arc was followed.
public struct PhaseAdherenceScore: Codable, Sendable {
    /// The phase type being evaluated.
    public let phase: SessionPhase

    /// Adherence score for this phase (0.0-1.0).
    public let score: Double

    /// How many songs actually played during this phase.
    public let actualSongCount: Int

    /// How many songs were planned for this phase.
    public let plannedSongCount: Int

    /// Average energy of songs played during this phase.
    public let avgActualEnergy: Double

    /// Target energy for this phase.
    public let targetEnergy: Double

    /// Average BPM of songs played during this phase.
    public let avgActualBPM: Double

    /// Target BPM for this phase.
    public let targetBPM: Double

    public init(
        phase: SessionPhase,
        score: Double,
        actualSongCount: Int,
        plannedSongCount: Int,
        avgActualEnergy: Double,
        targetEnergy: Double,
        avgActualBPM: Double,
        targetBPM: Double
    ) {
        self.phase = phase
        self.score = score
        self.actualSongCount = actualSongCount
        self.plannedSongCount = plannedSongCount
        self.avgActualEnergy = avgActualEnergy
        self.targetEnergy = targetEnergy
        self.avgActualBPM = avgActualBPM
        self.targetBPM = targetBPM
    }
}

// MARK: - Song Observation

/// A single song's actual energy/BPM observation for arc adherence evaluation.
public struct SongObservation: Codable, Sendable {
    /// Song index in the session (0-based).
    public let songIndex: Int

    /// Actual BPM of the song that was played.
    public let actualBPM: Double

    /// Actual energy level of the song that was played.
    public let actualEnergy: Double

    /// Whether the song was skipped.
    public let wasSkipped: Bool

    /// Listen percentage (0.0-1.0).
    public let listenPercentage: Double

    public init(
        songIndex: Int,
        actualBPM: Double,
        actualEnergy: Double,
        wasSkipped: Bool = false,
        listenPercentage: Double = 1.0
    ) {
        self.songIndex = songIndex
        self.actualBPM = actualBPM
        self.actualEnergy = actualEnergy
        self.wasSkipped = wasSkipped
        self.listenPercentage = listenPercentage
    }
}

// MARK: - SessionCritic

/// Evaluates session quality by measuring how well actual song selections
/// matched the planned arc. This produces the R_session reward component
/// for the multi-component delayed reward signal.
///
/// The critic answers: "Did the DJ follow its plan?"
///
/// Scoring dimensions:
/// 1. **BPM adherence**: How close were actual song BPMs to the arc targets?
/// 2. **Energy adherence**: How close were actual song energies to the arc targets?
/// 3. **Phase timing**: Were the right songs in the right phases?
/// 4. **Skip penalty**: Skips indicate the plan was wrong or poorly executed.
public struct SessionCritic: Sendable {

    // MARK: - Weights

    /// Weight for BPM adherence in the overall score.
    private let bpmWeight = 0.3

    /// Weight for energy adherence in the overall score.
    private let energyWeight = 0.3

    /// Weight for phase timing adherence.
    private let phaseTimingWeight = 0.2

    /// Weight for skip rate penalty.
    private let skipPenaltyWeight = 0.2

    public init() {}

    // MARK: - Public API

    /// Evaluates how well the actual session followed the planned arc.
    ///
    /// - Parameters:
    ///   - arc: The planned session arc from SessionPlanner.
    ///   - observations: Actual song BPM/energy observations from the session.
    /// - Returns: An ArcAdherenceResult with overall and per-phase scores.
    public func evaluate(
        arc: SessionArc,
        observations: [SongObservation]
    ) -> ArcAdherenceResult {
        guard !observations.isEmpty, !arc.phases.isEmpty else {
            return emptyResult(template: arc.template)
        }

        let planner = SessionPlanner()

        // Evaluate each observation against its expected arc phase
        var totalBPMDeviation = 0.0
        var totalEnergyDeviation = 0.0
        var skipCount = 0

        // Build per-phase buckets
        var phaseBuckets: [Int: [SongObservation]] = [:]
        for observation in observations {
            let phase = planner.currentPhase(for: arc, songsPlayed: observation.songIndex)
            let phaseIndex = arc.phases.firstIndex(where: {
                $0.phase == phase.phase && $0.targetBPM == phase.targetBPM
            }) ?? 0
            phaseBuckets[phaseIndex, default: []].append(observation)
        }

        // Calculate per-phase scores
        var phaseScores: [PhaseAdherenceScore] = []
        for (index, arcPhase) in arc.phases.enumerated() {
            let phaseObservations = phaseBuckets[index] ?? []
            let phaseScore = evaluatePhase(
                arcPhase: arcPhase,
                observations: phaseObservations
            )
            phaseScores.append(phaseScore)
        }

        // Calculate aggregate metrics
        for observation in observations {
            let expectedPhase = planner.currentPhase(for: arc, songsPlayed: observation.songIndex)
            totalBPMDeviation += abs(observation.actualBPM - expectedPhase.targetBPM)
            totalEnergyDeviation += abs(observation.actualEnergy - expectedPhase.targetEnergy)
            if observation.wasSkipped { skipCount += 1 }
        }

        let avgBPMDeviation = totalBPMDeviation / Double(observations.count)
        let avgEnergyDeviation = totalEnergyDeviation / Double(observations.count)

        // BPM adherence: 0-50 BPM deviation maps to 1.0-0.0
        let bpmAdherence = max(0.0, 1.0 - avgBPMDeviation / 50.0)

        // Energy adherence: 0-0.5 deviation maps to 1.0-0.0
        let energyAdherence = max(0.0, 1.0 - avgEnergyDeviation / 0.5)

        // Phase timing: average of per-phase scores
        let phaseTimingScore: Double
        if phaseScores.isEmpty {
            phaseTimingScore = 0.5
        } else {
            phaseTimingScore = phaseScores.reduce(0.0) { $0 + $1.score } / Double(phaseScores.count)
        }

        // Skip penalty: skip rate reduces the score
        let skipRate = Double(skipCount) / Double(observations.count)
        let skipScore = max(0.0, 1.0 - skipRate * 2.0)

        // Weighted overall score
        let overallScore = bpmAdherence * bpmWeight
            + energyAdherence * energyWeight
            + phaseTimingScore * phaseTimingWeight
            + skipScore * skipPenaltyWeight

        let result = ArcAdherenceResult(
            overallScore: min(1.0, max(0.0, overallScore)),
            phaseScores: phaseScores,
            template: arc.template,
            totalSongsPlayed: observations.count,
            avgEnergyDeviation: avgEnergyDeviation,
            avgBPMDeviation: avgBPMDeviation
        )

        logInfo(
            "SessionCritic: arc adherence=\(String(format: "%.2f", result.overallScore)), "
            + "bpmDev=\(String(format: "%.1f", avgBPMDeviation)), "
            + "energyDev=\(String(format: "%.2f", avgEnergyDeviation)), "
            + "skips=\(skipCount)/\(observations.count)",
            category: .sessionPlanner
        )

        return result
    }

    // MARK: - Phase Evaluation

    /// Evaluates how well a single phase was followed.
    private func evaluatePhase(
        arcPhase: ArcPhase,
        observations: [SongObservation]
    ) -> PhaseAdherenceScore {
        guard !observations.isEmpty else {
            return PhaseAdherenceScore(
                phase: arcPhase.phase,
                score: 0.5, // Neutral if no songs played in this phase
                actualSongCount: 0,
                plannedSongCount: arcPhase.songCount,
                avgActualEnergy: 0,
                targetEnergy: arcPhase.targetEnergy,
                avgActualBPM: 0,
                targetBPM: arcPhase.targetBPM
            )
        }

        let avgBPM = observations.reduce(0.0) { $0 + $1.actualBPM } / Double(observations.count)
        let avgEnergy = observations.reduce(0.0) { $0 + $1.actualEnergy } / Double(observations.count)

        // BPM fit: how close was average BPM to the phase target range?
        let bpmFit: Double
        if arcPhase.targetBPMRange.contains(avgBPM) {
            bpmFit = 1.0
        } else {
            let bpmDistance: Double
            if avgBPM < arcPhase.targetBPMRange.lowerBound {
                bpmDistance = arcPhase.targetBPMRange.lowerBound - avgBPM
            } else {
                bpmDistance = avgBPM - arcPhase.targetBPMRange.upperBound
            }
            bpmFit = max(0.0, 1.0 - bpmDistance / 30.0)
        }

        // Energy fit: how close was average energy to the phase target range?
        let energyFit: Double
        if arcPhase.targetEnergyRange.contains(avgEnergy) {
            energyFit = 1.0
        } else {
            let energyDistance: Double
            if avgEnergy < arcPhase.targetEnergyRange.lowerBound {
                energyDistance = arcPhase.targetEnergyRange.lowerBound - avgEnergy
            } else {
                energyDistance = avgEnergy - arcPhase.targetEnergyRange.upperBound
            }
            energyFit = max(0.0, 1.0 - energyDistance / 0.3)
        }

        // Song count fit: did we play the expected number of songs?
        let countRatio = Double(observations.count) / Double(max(1, arcPhase.songCount))
        let countFit = max(0.0, 1.0 - abs(1.0 - countRatio))

        let score = bpmFit * 0.35 + energyFit * 0.35 + countFit * 0.3

        return PhaseAdherenceScore(
            phase: arcPhase.phase,
            score: min(1.0, max(0.0, score)),
            actualSongCount: observations.count,
            plannedSongCount: arcPhase.songCount,
            avgActualEnergy: avgEnergy,
            targetEnergy: arcPhase.targetEnergy,
            avgActualBPM: avgBPM,
            targetBPM: arcPhase.targetBPM
        )
    }

    // MARK: - Helpers

    /// Returns a neutral result for an empty evaluation.
    private func emptyResult(template: ArcTemplate) -> ArcAdherenceResult {
        ArcAdherenceResult(
            overallScore: 0.5,
            phaseScores: [],
            template: template,
            totalSongsPlayed: 0,
            avgEnergyDeviation: 0,
            avgBPMDeviation: 0
        )
    }
}
