//
//  SessionPlannerTests.swift
//  ResonanceTests
//
//  Unit tests for SessionPlanner arc planning, phase tracking,
//  DJ energy mapping, and SessionCritic arc adherence scoring.
//

import XCTest
@testable import Resonance

final class SessionPlannerTests: XCTestCase {

    private var planner: SessionPlanner!

    override func setUp() {
        super.setUp()
        planner = SessionPlanner()
    }

    override func tearDown() {
        planner = nil
        super.tearDown()
    }

    // MARK: - Template Selection

    func test_planSession_workoutContext_selectsWorkoutTemplate() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 45
        )
        XCTAssertEqual(arc.template, .workoutBuildPeakCool)
        XCTAssertGreaterThan(arc.phases.count, 0)
    }

    func test_planSession_sleepContext_selectsSleepTemplate() {
        let state = StateVector(energy: 0.3, context: .preSleep)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .preSleep,
            estimatedDuration: 30
        )
        XCTAssertEqual(arc.template, .sleepWindDown)
    }

    func test_planSession_focusContext_selectsFocusTemplate() {
        let state = StateVector(energy: 0.5, context: .deepWork)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .deepWork,
            estimatedDuration: 60
        )
        XCTAssertEqual(arc.template, .focusSustainPlateau)
    }

    func test_planSession_morningContext_selectsMorningTemplate() {
        let state = StateVector(energy: 0.3, context: .morning)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .morning,
            estimatedDuration: 30
        )
        XCTAssertEqual(arc.template, .morningRise)
    }

    func test_planSession_commuteContext_selectsCommuteTemplate() {
        let state = StateVector(energy: 0.5, context: .commute)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .commute,
            estimatedDuration: 25
        )
        XCTAssertEqual(arc.template, .commuteEnergize)
    }

    func test_planSession_relaxationContext_selectsRelaxationTemplate() {
        let state = StateVector(energy: 0.5, context: .relaxation)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .relaxation,
            estimatedDuration: 30
        )
        XCTAssertEqual(arc.template, .relaxationDescend)
    }

    // MARK: - Workout BPM Ranges (Research-Backed: 100-170)

    func test_workoutArc_bpmRangesWithinResearchBounds() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 45
        )

        for phase in arc.phases {
            XCTAssertGreaterThanOrEqual(
                phase.targetBPMRange.lowerBound, 60,
                "Workout phase \(phase.phase) BPM lower bound too low"
            )
            XCTAssertLessThanOrEqual(
                phase.targetBPMRange.upperBound, 170,
                "Workout phase \(phase.phase) BPM upper bound too high"
            )
        }
    }

    func test_workoutArc_hasAllPhaseTypes() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 45
        )

        let phaseTypes = Set(arc.phases.map { $0.phase })
        XCTAssertTrue(phaseTypes.contains(.match), "Workout arc should have match phase")
        XCTAssertTrue(phaseTypes.contains(.shift), "Workout arc should have shift phase")
        XCTAssertTrue(phaseTypes.contains(.arrive), "Workout arc should have arrive phase")
        XCTAssertTrue(phaseTypes.contains(.sustain), "Workout arc should have sustain phase")
    }

    // MARK: - Sleep BPM Ranges (Research-Backed: 60-80)

    func test_sleepArc_bpmRangesWithinResearchBounds() {
        let state = StateVector(energy: 0.3, context: .preSleep)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .preSleep,
            estimatedDuration: 30
        )

        for phase in arc.phases {
            XCTAssertGreaterThanOrEqual(
                phase.targetBPMRange.lowerBound, 58,
                "Sleep phase \(phase.phase) BPM too low"
            )
            XCTAssertLessThanOrEqual(
                phase.targetBPMRange.upperBound, 85,
                "Sleep phase \(phase.phase) BPM too high"
            )
        }
    }

    func test_sleepArc_allPhasesPreferInstrumental() {
        let state = StateVector(energy: 0.3, context: .preSleep)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .preSleep,
            estimatedDuration: 30
        )

        for phase in arc.phases {
            XCTAssertTrue(
                phase.preferInstrumental,
                "Sleep phase \(phase.phase) should prefer instrumental"
            )
        }
    }

    func test_sleepArc_bpmDecreases() {
        let state = StateVector(energy: 0.3, context: .preSleep)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .preSleep,
            estimatedDuration: 30
        )

        // The last phase should have lower target BPM than the first
        let firstBPM = arc.phases.first!.targetBPM
        let lastBPM = arc.phases.last!.targetBPM
        XCTAssertLessThanOrEqual(
            lastBPM, firstBPM,
            "Sleep arc should decrease BPM from first to last phase"
        )
    }

    // MARK: - Focus BPM Ranges (Research-Backed: 60-100)

    func test_focusArc_bpmRangesWithinResearchBounds() {
        let state = StateVector(energy: 0.4, context: .deepWork)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .deepWork,
            estimatedDuration: 60
        )

        // The sustain phase (longest) should be within 60-100
        let sustainPhase = arc.phases.first(where: { $0.phase == .sustain })
        XCTAssertNotNil(sustainPhase)
        if let sustain = sustainPhase {
            XCTAssertGreaterThanOrEqual(sustain.targetBPMRange.lowerBound, 60)
            XCTAssertLessThanOrEqual(sustain.targetBPMRange.upperBound, 100)
        }
    }

    func test_focusArc_prefersInstrumental() {
        let state = StateVector(energy: 0.4, context: .deepWork)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .deepWork,
            estimatedDuration: 60
        )

        for phase in arc.phases {
            XCTAssertTrue(
                phase.preferInstrumental,
                "Focus phase \(phase.phase) should prefer instrumental"
            )
        }
    }

    // MARK: - Phase Tracking

    func test_currentPhase_firstSong_returnsMatchPhase() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 45
        )

        let phase = planner.currentPhase(for: arc, songsPlayed: 0)
        XCTAssertEqual(phase.phase, .match)
    }

    func test_currentPhase_pastAllPhases_returnsLastPhase() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 45
        )

        let phase = planner.currentPhase(for: arc, songsPlayed: 999)
        XCTAssertEqual(phase.phase, arc.phases.last!.phase)
    }

    func test_currentPhase_progressesThroughPhases() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 45
        )

        var lastPhaseIndex = 0
        for songIndex in 0..<arc.totalSongs {
            let phase = planner.currentPhase(for: arc, songsPlayed: songIndex)
            if let currentPhaseIndex = arc.phases.firstIndex(where: {
                $0.phase == phase.phase && $0.targetBPM == phase.targetBPM
            }) {
                XCTAssertGreaterThanOrEqual(
                    currentPhaseIndex, lastPhaseIndex,
                    "Phase should not go backward"
                )
                lastPhaseIndex = currentPhaseIndex
            }
        }
    }

    // MARK: - DJ Energy Level Abstraction

    func test_djEnergyLevel_zeroEnergy_returnsOne() {
        let level = SessionPlanner.djEnergyLevel(from: 0.0)
        XCTAssertEqual(level, 1)
    }

    func test_djEnergyLevel_halfEnergy_returnsFive() {
        let level = SessionPlanner.djEnergyLevel(from: 0.5)
        // 0.5 * 9 + 1 = 5.5, Int = 5
        XCTAssertEqual(level, 5)
    }

    func test_djEnergyLevel_fullEnergy_returnsTen() {
        let level = SessionPlanner.djEnergyLevel(from: 1.0)
        XCTAssertEqual(level, 10)
    }

    func test_djEnergyLevel_clampsNegative() {
        let level = SessionPlanner.djEnergyLevel(from: -0.5)
        XCTAssertEqual(level, 1)
    }

    func test_djEnergyLevel_clampsAboveOne() {
        let level = SessionPlanner.djEnergyLevel(from: 1.5)
        XCTAssertEqual(level, 10)
    }

    func test_djEnergyDescription_lowLevels() {
        XCTAssertEqual(SessionPlanner.djEnergyDescription(level: 1), "Very Calm")
        XCTAssertEqual(SessionPlanner.djEnergyDescription(level: 2), "Very Calm")
    }

    func test_djEnergyDescription_midLevels() {
        XCTAssertEqual(SessionPlanner.djEnergyDescription(level: 5), "Moderate")
        XCTAssertEqual(SessionPlanner.djEnergyDescription(level: 6), "Moderate")
    }

    func test_djEnergyDescription_highLevels() {
        XCTAssertEqual(SessionPlanner.djEnergyDescription(level: 9), "Peak Energy")
        XCTAssertEqual(SessionPlanner.djEnergyDescription(level: 10), "Peak Energy")
    }

    // MARK: - Duration Scaling

    func test_longerDuration_producesMoreSongs() {
        let state = StateVector(energy: 0.5, context: .workout)
        let shortArc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 15
        )
        let longArc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 60
        )

        XCTAssertGreaterThan(
            longArc.totalSongs, shortArc.totalSongs,
            "Longer duration should produce more songs"
        )
    }

    // MARK: - Energy Trajectory

    func test_energyTrajectory_hasEntriesForAllSongs() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 30
        )

        let trajectory = arc.energyTrajectory
        XCTAssertEqual(trajectory.count, arc.totalSongs)
    }

    func test_energyTrajectory_valuesAreNormalized() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 30
        )

        for entry in arc.energyTrajectory {
            XCTAssertGreaterThanOrEqual(entry.energy, 0.0)
            XCTAssertLessThanOrEqual(entry.energy, 1.0)
        }
    }

    // MARK: - Arc DJ Energy Level

    func test_djEnergyLevelAtSongIndex_returnsValidRange() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 30
        )

        for i in 0..<arc.totalSongs {
            let level = arc.djEnergyLevel(at: i)
            XCTAssertGreaterThanOrEqual(level, 1)
            XCTAssertLessThanOrEqual(level, 10)
        }
    }

    // MARK: - ArcPhase Properties

    func test_arcPhase_targetBPM_isMidpoint() {
        let phase = ArcPhase(
            phase: .sustain,
            targetBPMRange: 60...100,
            targetEnergyRange: 0.3...0.5,
            songCount: 5
        )
        XCTAssertEqual(phase.targetBPM, 80.0, accuracy: 0.01)
    }

    func test_arcPhase_targetEnergy_isMidpoint() {
        let phase = ArcPhase(
            phase: .sustain,
            targetBPMRange: 60...100,
            targetEnergyRange: 0.2...0.8,
            songCount: 5
        )
        XCTAssertEqual(phase.targetEnergy, 0.5, accuracy: 0.01)
    }
}

// MARK: - SessionCritic Tests

final class SessionCriticTests: XCTestCase {

    private var critic: SessionCritic!
    private var planner: SessionPlanner!

    override func setUp() {
        super.setUp()
        critic = SessionCritic()
        planner = SessionPlanner()
    }

    override func tearDown() {
        critic = nil
        planner = nil
        super.tearDown()
    }

    // MARK: - Perfect Adherence

    func test_evaluate_perfectAdherence_highScore() {
        let state = StateVector(energy: 0.5, context: .relaxation)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .relaxation,
            estimatedDuration: 30
        )

        // Create observations that match the arc perfectly
        var observations: [SongObservation] = []
        for i in 0..<arc.totalSongs {
            let phase = planner.currentPhase(for: arc, songsPlayed: i)
            observations.append(SongObservation(
                songIndex: i,
                actualBPM: phase.targetBPM,
                actualEnergy: phase.targetEnergy
            ))
        }

        let result = critic.evaluate(arc: arc, observations: observations)
        XCTAssertGreaterThan(result.overallScore, 0.8, "Perfect adherence should score > 0.8")
    }

    // MARK: - Poor Adherence

    func test_evaluate_totalDivergence_lowScore() {
        let state = StateVector(energy: 0.5, context: .relaxation)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .relaxation,
            estimatedDuration: 30
        )

        // Create observations that are completely off from the arc
        var observations: [SongObservation] = []
        for i in 0..<arc.totalSongs {
            let phase = planner.currentPhase(for: arc, songsPlayed: i)
            observations.append(SongObservation(
                songIndex: i,
                actualBPM: phase.targetBPM + 60, // Way off
                actualEnergy: 1.0 - phase.targetEnergy // Inverted
            ))
        }

        let result = critic.evaluate(arc: arc, observations: observations)
        XCTAssertLessThan(result.overallScore, 0.5, "Divergent session should score < 0.5")
    }

    // MARK: - Skip Penalty

    func test_evaluate_highSkipRate_reducesScore() {
        let state = StateVector(energy: 0.5, context: .relaxation)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .relaxation,
            estimatedDuration: 30
        )

        // Create observations with high skip rate but good BPM/energy
        var observations: [SongObservation] = []
        for i in 0..<arc.totalSongs {
            let phase = planner.currentPhase(for: arc, songsPlayed: i)
            observations.append(SongObservation(
                songIndex: i,
                actualBPM: phase.targetBPM,
                actualEnergy: phase.targetEnergy,
                wasSkipped: true,
                listenPercentage: 0.1
            ))
        }

        let resultWithSkips = critic.evaluate(arc: arc, observations: observations)

        // Compare with no-skip version
        var noSkipObservations: [SongObservation] = []
        for i in 0..<arc.totalSongs {
            let phase = planner.currentPhase(for: arc, songsPlayed: i)
            noSkipObservations.append(SongObservation(
                songIndex: i,
                actualBPM: phase.targetBPM,
                actualEnergy: phase.targetEnergy
            ))
        }

        let resultNoSkips = critic.evaluate(arc: arc, observations: noSkipObservations)

        XCTAssertLessThan(
            resultWithSkips.overallScore,
            resultNoSkips.overallScore,
            "High skip rate should reduce the adherence score"
        )
    }

    // MARK: - Empty Session

    func test_evaluate_emptyObservations_returnsNeutral() {
        let state = StateVector(energy: 0.5, context: .relaxation)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .relaxation,
            estimatedDuration: 30
        )

        let result = critic.evaluate(arc: arc, observations: [])
        XCTAssertEqual(result.overallScore, 0.5, "Empty session should return neutral 0.5")
        XCTAssertEqual(result.totalSongsPlayed, 0)
    }

    // MARK: - Per-Phase Scores

    func test_evaluate_producesPerPhaseScores() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 45
        )

        var observations: [SongObservation] = []
        for i in 0..<arc.totalSongs {
            let phase = planner.currentPhase(for: arc, songsPlayed: i)
            observations.append(SongObservation(
                songIndex: i,
                actualBPM: phase.targetBPM,
                actualEnergy: phase.targetEnergy
            ))
        }

        let result = critic.evaluate(arc: arc, observations: observations)
        XCTAssertEqual(
            result.phaseScores.count, arc.phases.count,
            "Should have one score per arc phase"
        )

        for phaseScore in result.phaseScores {
            XCTAssertGreaterThanOrEqual(phaseScore.score, 0.0)
            XCTAssertLessThanOrEqual(phaseScore.score, 1.0)
        }
    }

    // MARK: - Result Properties

    func test_arcAdherenceResult_hasCorrectTemplate() {
        let state = StateVector(energy: 0.5, context: .workout)
        let arc = planner.planSession(
            currentState: state,
            targetContext: .workout,
            estimatedDuration: 30
        )

        let result = critic.evaluate(arc: arc, observations: [
            SongObservation(songIndex: 0, actualBPM: 100, actualEnergy: 0.5)
        ])

        XCTAssertEqual(result.template, .workoutBuildPeakCool)
        XCTAssertEqual(result.totalSongsPlayed, 1)
    }
}
