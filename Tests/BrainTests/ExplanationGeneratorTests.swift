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
}
