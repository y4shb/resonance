//
//  ExplanationGeneratorTests.swift
//  ResonanceTests
//
//  Unit tests for ExplanationGenerator: full/short explanation output,
//  session start messaging, stress context, and factor ordering.
//

import XCTest
@testable import Resonance

final class ExplanationGeneratorTests: XCTestCase {

    private var generator: ExplanationGenerator!

    override func setUp() {
        super.setUp()
        generator = ExplanationGenerator()
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    // MARK: - Basic Output

    func test_generate_producesNonEmptyExplanations() {
        let score = SongScore.placeholder()
        let state = StateVector(inferredNeed: .maintain)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        XCTAssertFalse(explanation.full.isEmpty, "Full explanation should not be empty")
        XCTAssertFalse(explanation.short.isEmpty, "Short explanation should not be empty")
        XCTAssertFalse(explanation.stateDescription.isEmpty, "State description should not be empty")
        XCTAssertFalse(explanation.needDescription.isEmpty, "Need description should not be empty")
    }

    // MARK: - Session Start

    func test_generate_sessionStart_includesStartingMessage() {
        let score = SongScore.placeholder()
        let state = StateVector(inferredNeed: .maintain)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: true
        )

        XCTAssertTrue(
            explanation.full.contains("Starting your session"),
            "Session start explanation should include 'Starting your session'"
        )
    }

    func test_generate_notSessionStart_excludesStartingMessage() {
        let score = SongScore.placeholder()
        let state = StateVector(inferredNeed: .maintain)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        XCTAssertFalse(
            explanation.full.contains("Starting your session"),
            "Non-session-start should not include 'Starting your session'"
        )
    }

    // MARK: - High Stress Context

    func test_generate_highStress_familiarTrackMentionsComforting() {
        let score = SongScore(
            songId: UUID(),
            songTitle: "Comfort Song",
            artistName: "Artist",
            albumName: "Album",
            bpm: 100,
            bpmMatchScore: 0.8,
            energyMatchScore: 0.7,
            familiarityScore: 0.8, // High familiarity
            historicalEffectScore: 0.5,
            contextAlignmentScore: 0.6,
            recencyPenalty: 0,
            timeOfDayScore: 0.9,
            finalScore: 0.75,
            confidence: 0.8,
            explanationComponents: [
                ExplanationComponent(factor: "Familiarity", contribution: 0.8, description: "Familiar track (comforting)")
            ]
        )
        let state = StateVector(
            stress: 0.8, // High stress
            inferredNeed: .calm
        )

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // The factors should include a familiarity factor mentioning comforting/stress
        let hasFamiliarityFactor = explanation.factors.contains { factor in
            factor.name == "Familiarity" && factor.description.contains("comforting")
        }
        XCTAssertTrue(hasFamiliarityFactor, "High stress + familiar track should mention comforting")
    }

    // MARK: - Factor Sort Order

    func test_generate_factorsSortedByContributionDescending() {
        let score = SongScore(
            songId: UUID(),
            songTitle: "Test Song",
            artistName: "Artist",
            albumName: "Album",
            bpm: 120,
            bpmMatchScore: 0.5,
            energyMatchScore: 0.9,
            familiarityScore: 0.6,
            historicalEffectScore: 0.7,
            contextAlignmentScore: 0.3,
            recencyPenalty: 0,
            timeOfDayScore: 0.8,
            finalScore: 0.7,
            confidence: 0.8,
            explanationComponents: []
        )
        let state = StateVector(inferredNeed: .maintain)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // Verify factors are sorted by contribution descending
        for i in 0..<(explanation.factors.count - 1) {
            XCTAssertGreaterThanOrEqual(
                explanation.factors[i].contribution,
                explanation.factors[i + 1].contribution,
                "Factors should be sorted by contribution descending"
            )
        }
    }

    // MARK: - Need Descriptions

    func test_generate_energizeNeed_mentionsEnergy() {
        let score = SongScore.placeholder()
        let state = StateVector(inferredNeed: .energize)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        XCTAssertTrue(
            explanation.needDescription.lowercased().contains("energy") ||
            explanation.needDescription.lowercased().contains("boost"),
            "Energize need should mention energy or boost"
        )
    }

    func test_generate_calmNeed_mentionsRelax() {
        let score = SongScore.placeholder()
        let state = StateVector(inferredNeed: .calm)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        XCTAssertTrue(
            explanation.needDescription.lowercased().contains("relax"),
            "Calm need should mention relax"
        )
    }

    // MARK: - Focus Need Description

    func test_generate_focusNeed_mentionsFocusOrConcentrate() {
        let score = SongScore.placeholder()
        let state = StateVector(inferredNeed: .focus)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        let desc = explanation.needDescription.lowercased()
        XCTAssertTrue(
            desc.contains("focus") || desc.contains("concentrat"),
            "Focus need should mention focus or concentrate/concentration, got: \(explanation.needDescription)"
        )
    }

    // MARK: - Maintain Need Description

    func test_generate_maintainNeed_mentionsMaintainOrKeep() {
        let score = SongScore.placeholder()
        let state = StateVector(inferredNeed: .maintain)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        let desc = explanation.needDescription.lowercased()
        XCTAssertTrue(
            desc.contains("maintain") || desc.contains("keep"),
            "Maintain need should mention maintain or keep, got: \(explanation.needDescription)"
        )
    }

    // MARK: - Transition Need Description

    func test_generate_transitionNeed_mentionsTransitionOrShift() {
        let score = SongScore.placeholder()
        let state = StateVector(inferredNeed: .transition)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        let desc = explanation.needDescription.lowercased()
        XCTAssertTrue(
            desc.contains("transition") || desc.contains("shift"),
            "Transition need should mention transition or shift, got: \(explanation.needDescription)"
        )
    }

    // MARK: - Confidence Score Effects

    func test_generate_highConfidence_fullExplanationIncludesFactorDetails() {
        let score = SongScore(
            songId: UUID(),
            songTitle: "High Confidence Song",
            artistName: "Artist",
            albumName: "Album",
            bpm: 130,
            bpmMatchScore: 0.95,
            energyMatchScore: 0.9,
            familiarityScore: 0.7,
            historicalEffectScore: 0.8,
            contextAlignmentScore: 0.85,
            recencyPenalty: 0,
            timeOfDayScore: 0.9,
            finalScore: 0.9,
            confidence: 0.95,
            explanationComponents: []
        )
        let state = StateVector(inferredNeed: .energize)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // High-scoring factors should produce strong descriptions in the full explanation
        XCTAssertTrue(
            explanation.full.contains("closely matches") || explanation.full.contains("great fit"),
            "High confidence/high scoring song should have strong factor descriptions in full explanation"
        )
    }

    func test_generate_lowConfidence_factorsReflectWeakerScores() {
        let score = SongScore(
            songId: UUID(),
            songTitle: "Low Confidence Song",
            artistName: "Artist",
            albumName: "Album",
            bpm: 80,
            bpmMatchScore: 0.2,
            energyMatchScore: 0.3,
            familiarityScore: 0.1,
            historicalEffectScore: 0.3,
            contextAlignmentScore: 0.2,
            recencyPenalty: 0,
            timeOfDayScore: 0.3,
            finalScore: 0.25,
            confidence: 0.2,
            explanationComponents: []
        )
        let state = StateVector(inferredNeed: .maintain)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // Low scoring factors should produce weaker/exploratory descriptions
        let hasWeakDescription = explanation.factors.contains { factor in
            factor.description.contains("differs") ||
            factor.description.contains("moderate") ||
            factor.description.contains("mixed")
        }
        XCTAssertTrue(
            hasWeakDescription,
            "Low confidence/low scoring song should have weaker factor descriptions indicating exploration"
        )
    }

    // MARK: - Multiple Explanation Components

    func test_generate_multipleFactors_allTopFactorsAppearInFullExplanation() {
        let score = SongScore(
            songId: UUID(),
            songTitle: "Multi Factor Song",
            artistName: "Artist",
            albumName: "Album",
            bpm: 120,
            bpmMatchScore: 0.9,
            energyMatchScore: 0.85,
            familiarityScore: 0.7,
            historicalEffectScore: 0.8,
            contextAlignmentScore: 0.6,
            recencyPenalty: 0,
            timeOfDayScore: 0.8,
            finalScore: 0.8,
            confidence: 0.85,
            explanationComponents: []
        )
        let state = StateVector(inferredNeed: .energize)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // Get the top 3 factors by contribution
        let topThreeFactors = explanation.factors.prefix(3)

        // Each of the top 3 factor descriptions should appear in the full explanation
        for factor in topThreeFactors {
            XCTAssertTrue(
                explanation.full.contains(factor.description),
                "Full explanation should contain top factor description: '\(factor.description)'"
            )
        }
    }

    // MARK: - Workout Context

    func test_generate_workoutContext_referencesWorkout() {
        let score = SongScore.placeholder()
        let state = StateVector(
            context: .workout,
            inferredNeed: .energize
        )

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // The context factor should mention workout
        let hasWorkoutReference = explanation.factors.contains { factor in
            factor.description.lowercased().contains("workout")
        }
        let stateHasWorkout = explanation.stateDescription.lowercased().contains("workout")

        XCTAssertTrue(
            hasWorkoutReference || stateHasWorkout,
            "Workout context should produce a reference to workout in factors or state description"
        )
    }

    // MARK: - Pre-Sleep Context

    func test_generate_preSleepContext_referencesSleepOrWindDown() {
        let score = SongScore.placeholder()
        let state = StateVector(
            context: .preSleep,
            inferredNeed: .calm
        )

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // The context factor or state description should mention pre-sleep
        let hasSleepReference = explanation.factors.contains { factor in
            factor.description.lowercased().contains("sleep") ||
            factor.description.lowercased().contains("pre-sleep")
        }
        let stateHasSleep = explanation.stateDescription.lowercased().contains("sleep") ||
                            explanation.stateDescription.lowercased().contains("pre-sleep")

        XCTAssertTrue(
            hasSleepReference || stateHasSleep,
            "Pre-sleep context should reference sleep or pre-sleep in factors or state description"
        )
    }

    // MARK: - Factor Count Maximum

    func test_generate_factorCountInFullExplanation_doesNotExceedThree() {
        let score = SongScore(
            songId: UUID(),
            songTitle: "Many Factors Song",
            artistName: "Artist",
            albumName: "Album",
            bpm: 120,
            bpmMatchScore: 0.9,
            energyMatchScore: 0.85,
            familiarityScore: 0.7,
            historicalEffectScore: 0.8,
            contextAlignmentScore: 0.75,
            recencyPenalty: 0,
            timeOfDayScore: 0.8,
            finalScore: 0.8,
            confidence: 0.85,
            explanationComponents: []
        )
        let state = StateVector(inferredNeed: .energize)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // Full explanation uses bullet points for factors (prefix "• ")
        let bulletCount = explanation.full.components(separatedBy: "• ").count - 1
        XCTAssertLessThanOrEqual(
            bulletCount,
            3,
            "Full explanation should contain at most 3 factor bullet points, found \(bulletCount)"
        )
    }

    // MARK: - State Description Content

    func test_generate_stateDescription_includesRelevantStateInfo() {
        let score = SongScore.placeholder()
        let state = StateVector(
            energy: 0.9,
            stress: 0.8,
            context: .work,
            inferredNeed: .focus
        )

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        let desc = explanation.stateDescription.lowercased()

        // High energy (>0.7) should mention "high energy"
        XCTAssertTrue(
            desc.contains("high energy"),
            "State description should mention high energy for energy=0.9, got: \(explanation.stateDescription)"
        )

        // High stress (>0.6) should mention "elevated stress"
        XCTAssertTrue(
            desc.contains("elevated stress"),
            "State description should mention elevated stress for stress=0.8, got: \(explanation.stateDescription)"
        )

        // Work context should appear
        XCTAssertTrue(
            desc.contains("work"),
            "State description should include context 'work', got: \(explanation.stateDescription)"
        )
    }

    // MARK: - Empty Explanation Components

    func test_generate_minimalFactors_stillProducesValidOutput() {
        // bpm=0 skips Tempo factor, historicalEffectScore=0.5 skips History,
        // familiarityScore<=0.3 skips Familiarity. Only Energy and Context remain.
        let score = SongScore(
            songId: UUID(),
            songTitle: "Minimal Song",
            artistName: "Artist",
            albumName: "Album",
            bpm: 0,
            bpmMatchScore: 0.0,
            energyMatchScore: 0.5,
            familiarityScore: 0.2,
            historicalEffectScore: 0.5,
            contextAlignmentScore: 0.4,
            recencyPenalty: 0,
            timeOfDayScore: 0.5,
            finalScore: 0.4,
            confidence: 0.5,
            explanationComponents: []
        )
        let state = StateVector(inferredNeed: .maintain)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // Should still produce valid, non-empty output
        XCTAssertFalse(explanation.full.isEmpty, "Full explanation should not be empty even with minimal factors")
        XCTAssertFalse(explanation.short.isEmpty, "Short explanation should not be empty even with minimal factors")
        XCTAssertFalse(explanation.stateDescription.isEmpty, "State description should not be empty")
        XCTAssertFalse(explanation.needDescription.isEmpty, "Need description should not be empty")

        // Should have exactly 2 factors (Energy and Context)
        XCTAssertEqual(
            explanation.factors.count,
            2,
            "With bpm=0, historicalEffect=0.5, familiarity<=0.3, only Energy and Context factors should remain"
        )
    }

    // MARK: - Single Component

    func test_generate_singleDominantFactor_worksCorrectly() {
        // Only Energy factor should be strong; others minimal or skipped
        let score = SongScore(
            songId: UUID(),
            songTitle: "Single Factor Song",
            artistName: "Artist",
            albumName: "Album",
            bpm: 0,       // Skip Tempo
            bpmMatchScore: 0.0,
            energyMatchScore: 0.95,
            familiarityScore: 0.1,  // Skip Familiarity (<=0.3)
            historicalEffectScore: 0.5, // Skip History (==0.5)
            contextAlignmentScore: 0.1,
            recencyPenalty: 0,
            timeOfDayScore: 0.5,
            finalScore: 0.5,
            confidence: 0.7,
            explanationComponents: []
        )
        let state = StateVector(inferredNeed: .maintain)

        let explanation = generator.generate(
            score: score,
            state: state,
            isSessionStart: false
        )

        // Energy and Context are always added; Energy should be dominant
        XCTAssertEqual(
            explanation.factors.first?.name,
            "Energy",
            "With only Energy having a high score, it should be the top factor"
        )
        XCTAssertTrue(
            explanation.factors.first!.contribution > explanation.factors.last!.contribution,
            "The dominant Energy factor should have a higher contribution than Context"
        )

        // Full explanation should still be valid with the single strong factor
        XCTAssertTrue(
            explanation.full.contains("great fit") || explanation.full.contains("Energy"),
            "Single dominant factor (energy=0.95) should produce a strong description"
        )
    }
}
