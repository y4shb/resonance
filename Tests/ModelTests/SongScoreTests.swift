//
//  SongScoreTests.swift
//  ResonanceTests
//
//  Unit tests for SongScore and ExplanationComponent:
//  placeholder factory, explanation formatting, score percentage, and Comparable.
//

import XCTest
@testable import Resonance

final class SongScoreTests: XCTestCase {

    // MARK: - Placeholder Factory

    func test_placeholder_createsValidScore() {
        let score = SongScore.placeholder()
        XCTAssertEqual(score.songTitle, "Test Song")
        XCTAssertEqual(score.artistName, "Test Artist")
        XCTAssertEqual(score.albumName, "Test Album")
        XCTAssertEqual(score.bpm, 120)
        XCTAssertEqual(score.finalScore, 0.8, accuracy: 0.001)
        XCTAssertEqual(score.confidence, 0.8, accuracy: 0.001)
        XCTAssertFalse(score.explanationComponents.isEmpty)
    }

    func test_placeholder_customValues() {
        let score = SongScore.placeholder(
            songTitle: "Custom",
            artistName: "Custom Artist",
            score: 0.5
        )
        XCTAssertEqual(score.songTitle, "Custom")
        XCTAssertEqual(score.artistName, "Custom Artist")
        XCTAssertEqual(score.finalScore, 0.5, accuracy: 0.001)
    }

    // MARK: - Short Explanation

    func test_shortExplanation_returnsTopComponentDescription() {
        let components = [
            ExplanationComponent(factor: "BPM", contribution: 0.3, description: "Tempo matches"),
            ExplanationComponent(factor: "Energy", contribution: 0.9, description: "Energy is great"),
            ExplanationComponent(factor: "Context", contribution: 0.5, description: "Fits context")
        ]
        let score = makeScore(explanationComponents: components)

        // Top component by contribution is Energy (0.9)
        XCTAssertEqual(score.shortExplanation, "Energy is great")
    }

    func test_shortExplanation_noComponents_returnsDefault() {
        let score = makeScore(explanationComponents: [])
        XCTAssertEqual(score.shortExplanation, "Selected for you")
    }

    // MARK: - Full Explanation

    func test_fullExplanation_includesBulletPoints() {
        let components = [
            ExplanationComponent(factor: "BPM", contribution: 0.8, description: "Great tempo"),
            ExplanationComponent(factor: "Energy", contribution: 0.7, description: "Good energy")
        ]
        let score = makeScore(explanationComponents: components)

        let full = score.fullExplanation
        XCTAssertTrue(full.contains("Why this song?"), "Full explanation should start with 'Why this song?'")
        XCTAssertTrue(full.contains("\u{2022}"), "Full explanation should contain bullet points")
    }

    func test_fullExplanation_limitsToTop3() {
        let components = [
            ExplanationComponent(factor: "A", contribution: 0.9, description: "Factor A"),
            ExplanationComponent(factor: "B", contribution: 0.8, description: "Factor B"),
            ExplanationComponent(factor: "C", contribution: 0.7, description: "Factor C"),
            ExplanationComponent(factor: "D", contribution: 0.6, description: "Factor D"),
            ExplanationComponent(factor: "E", contribution: 0.5, description: "Factor E")
        ]
        let score = makeScore(explanationComponents: components)

        let full = score.fullExplanation
        // Should contain top 3 but not the 4th/5th
        let bulletCount = full.components(separatedBy: "\u{2022}").count - 1
        XCTAssertLessThanOrEqual(bulletCount, 3, "Full explanation should show at most 3 factors")
    }

    // MARK: - Score Percentage

    func test_scorePercentage_formats_correctly() {
        let score = makeScore(finalScore: 0.85)
        XCTAssertEqual(score.scorePercentage, "85%")
    }

    func test_scorePercentage_zero() {
        let score = makeScore(finalScore: 0.0)
        XCTAssertEqual(score.scorePercentage, "0%")
    }

    func test_scorePercentage_full() {
        let score = makeScore(finalScore: 1.0)
        XCTAssertEqual(score.scorePercentage, "100%")
    }

    // MARK: - Comparable

    func test_comparable_sortsBy_finalScore() {
        let low = makeScore(finalScore: 0.3)
        let mid = makeScore(finalScore: 0.6)
        let high = makeScore(finalScore: 0.9)

        XCTAssertTrue(low < mid)
        XCTAssertTrue(mid < high)
        XCTAssertFalse(high < low)
    }

    func test_comparable_sortedArray() {
        let scores = [
            makeScore(finalScore: 0.5),
            makeScore(finalScore: 0.9),
            makeScore(finalScore: 0.1),
            makeScore(finalScore: 0.7)
        ]

        let sorted = scores.sorted()
        XCTAssertEqual(sorted[0].finalScore, 0.1, accuracy: 0.001)
        XCTAssertEqual(sorted[1].finalScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(sorted[2].finalScore, 0.7, accuracy: 0.001)
        XCTAssertEqual(sorted[3].finalScore, 0.9, accuracy: 0.001)
    }

    // MARK: - Identifiable

    func test_identifiable_uniqueIds() {
        let a = SongScore.placeholder()
        let b = SongScore.placeholder()
        XCTAssertNotEqual(a.id, b.id, "Each SongScore should have a unique id")
    }

    // MARK: - ExplanationComponent

    func test_explanationComponent_properties() {
        let component = ExplanationComponent(
            factor: "Tempo",
            contribution: 0.85,
            description: "Great tempo match"
        )
        XCTAssertEqual(component.factor, "Tempo")
        XCTAssertEqual(component.contribution, 0.85, accuracy: 0.001)
        XCTAssertEqual(component.description, "Great tempo match")
    }

    func test_explanationComponent_codableRoundTrip() throws {
        let original = ExplanationComponent(
            factor: "Energy",
            contribution: 0.7,
            description: "Energy level fits"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExplanationComponent.self, from: data)

        XCTAssertEqual(decoded.factor, "Energy")
        XCTAssertEqual(decoded.contribution, 0.7, accuracy: 0.001)
        XCTAssertEqual(decoded.description, "Energy level fits")
    }

    // MARK: - Equatable

    func test_equatable_sameFinalScore_areEqual() {
        let a = makeScore(finalScore: 0.75)
        let b = makeScore(finalScore: 0.75)
        XCTAssertEqual(a, b, "Two SongScores with the same finalScore should be equal")
    }

    func test_equatable_differentFinalScore_areNotEqual() {
        let a = makeScore(finalScore: 0.75)
        let b = makeScore(finalScore: 0.80)
        XCTAssertNotEqual(a, b, "Two SongScores with different finalScores should not be equal")
    }

    // MARK: - Short Explanation (equal contributions)

    func test_shortExplanation_allSameContribution_returnsDeterministicResult() {
        let components = [
            ExplanationComponent(factor: "A", contribution: 0.5, description: "Factor A"),
            ExplanationComponent(factor: "B", contribution: 0.5, description: "Factor B"),
            ExplanationComponent(factor: "C", contribution: 0.5, description: "Factor C")
        ]
        let score = makeScore(explanationComponents: components)

        // When all contributions are equal, max(by:) returns the last element
        // that ties. The important thing is it returns a consistent, non-default result.
        let explanation = score.shortExplanation
        XCTAssertNotEqual(explanation, "Selected for you",
                          "Should return a component description, not the default fallback")
        let validDescriptions = components.map(\.description)
        XCTAssertTrue(validDescriptions.contains(explanation),
                      "shortExplanation should be one of the component descriptions")
    }

    // MARK: - Score Percentage (edge cases)

    func test_scorePercentage_fractionalValue() {
        let score = makeScore(finalScore: 0.333)
        // Int(0.333 * 100) = Int(33.3) = 33
        XCTAssertEqual(score.scorePercentage, "33%")
    }

    func test_scorePercentage_greaterThanOne() {
        let score = makeScore(finalScore: 1.5)
        // Int(1.5 * 100) = Int(150.0) = 150
        XCTAssertEqual(score.scorePercentage, "150%")
    }

    // MARK: - ExplanationComponent Sorting

    func test_explanationComponent_sortingByContribution() {
        let low = ExplanationComponent(factor: "Low", contribution: 0.1, description: "Low factor")
        let mid = ExplanationComponent(factor: "Mid", contribution: 0.5, description: "Mid factor")
        let high = ExplanationComponent(factor: "High", contribution: 0.9, description: "High factor")

        let sorted = [mid, low, high].sorted { $0.contribution > $1.contribution }
        XCTAssertEqual(sorted[0].factor, "High")
        XCTAssertEqual(sorted[1].factor, "Mid")
        XCTAssertEqual(sorted[2].factor, "Low")
    }

    // MARK: - Extreme Final Scores

    func test_songScore_veryHighFinalScore() {
        let score = makeScore(finalScore: 0.99)
        XCTAssertEqual(score.finalScore, 0.99, accuracy: 0.001)
        XCTAssertEqual(score.scorePercentage, "99%")
    }

    func test_songScore_veryLowFinalScore() {
        let score = makeScore(finalScore: 0.01)
        XCTAssertEqual(score.finalScore, 0.01, accuracy: 0.001)
        XCTAssertEqual(score.scorePercentage, "1%")
    }

    // MARK: - Confidence Preservation

    func test_confidence_isPreservedCorrectly() {
        let score = makeDetailedScore(confidence: 0.42)
        XCTAssertEqual(score.confidence, 0.42, accuracy: 0.001)
    }

    func test_confidence_zeroValue() {
        let score = makeDetailedScore(confidence: 0.0)
        XCTAssertEqual(score.confidence, 0.0, accuracy: 0.001)
    }

    func test_confidence_fullValue() {
        let score = makeDetailedScore(confidence: 1.0)
        XCTAssertEqual(score.confidence, 1.0, accuracy: 0.001)
    }

    // MARK: - All Component Score Fields

    func test_allComponentScoreFields_arePreserved() {
        let score = SongScore(
            songId: UUID(),
            songTitle: "Fields Test",
            artistName: "Artist",
            albumName: "Album",
            bpm: 140,
            bpmMatchScore: 0.11,
            energyMatchScore: 0.22,
            familiarityScore: 0.33,
            historicalEffectScore: 0.44,
            contextAlignmentScore: 0.55,
            recencyPenalty: 0.66,
            timeOfDayScore: 0.77,
            finalScore: 0.88,
            confidence: 0.99,
            explanationComponents: []
        )

        XCTAssertEqual(score.bpmMatchScore, 0.11, accuracy: 0.001)
        XCTAssertEqual(score.energyMatchScore, 0.22, accuracy: 0.001)
        XCTAssertEqual(score.familiarityScore, 0.33, accuracy: 0.001)
        XCTAssertEqual(score.historicalEffectScore, 0.44, accuracy: 0.001)
        XCTAssertEqual(score.contextAlignmentScore, 0.55, accuracy: 0.001)
        XCTAssertEqual(score.recencyPenalty, 0.66, accuracy: 0.001)
        XCTAssertEqual(score.timeOfDayScore, 0.77, accuracy: 0.001)
        XCTAssertEqual(score.finalScore, 0.88, accuracy: 0.001)
        XCTAssertEqual(score.confidence, 0.99, accuracy: 0.001)
        XCTAssertEqual(score.bpm, 140, accuracy: 0.001)
    }

    // MARK: - Placeholder Explanation Components

    func test_placeholder_returnsNonEmptyExplanationComponents() {
        let score = SongScore.placeholder()
        XCTAssertFalse(score.explanationComponents.isEmpty,
                       "placeholder() should include at least one explanation component")
        let first = score.explanationComponents[0]
        XCTAssertFalse(first.factor.isEmpty, "Component factor should not be empty")
        XCTAssertFalse(first.description.isEmpty, "Component description should not be empty")
        XCTAssertGreaterThan(first.contribution, 0.0, "Component contribution should be positive")
    }

    // MARK: - ExplanationComponent Codable (ID preservation)

    func test_explanationComponent_codablePreservesId() throws {
        let fixedId = UUID()
        let original = ExplanationComponent(
            id: fixedId,
            factor: "Test",
            contribution: 0.5,
            description: "Test description"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExplanationComponent.self, from: data)

        XCTAssertEqual(decoded.id, fixedId, "Codable round-trip should preserve the component id")
    }

    // MARK: - Helpers

    private func makeScore(
        finalScore: Double = 0.7,
        explanationComponents: [ExplanationComponent] = []
    ) -> SongScore {
        SongScore(
            songId: UUID(),
            songTitle: "Test",
            artistName: "Artist",
            albumName: "Album",
            bpm: 120,
            bpmMatchScore: 0.8,
            energyMatchScore: 0.7,
            familiarityScore: 0.5,
            historicalEffectScore: 0.5,
            contextAlignmentScore: 0.6,
            recencyPenalty: 0,
            timeOfDayScore: 0.9,
            finalScore: finalScore,
            confidence: 0.8,
            explanationComponents: explanationComponents
        )
    }

    private func makeDetailedScore(
        bpmMatchScore: Double = 0.8,
        energyMatchScore: Double = 0.7,
        familiarityScore: Double = 0.5,
        historicalEffectScore: Double = 0.5,
        contextAlignmentScore: Double = 0.6,
        recencyPenalty: Double = 0.0,
        timeOfDayScore: Double = 0.9,
        finalScore: Double = 0.7,
        confidence: Double = 0.8,
        explanationComponents: [ExplanationComponent] = []
    ) -> SongScore {
        SongScore(
            songId: UUID(),
            songTitle: "Detailed Test",
            artistName: "Artist",
            albumName: "Album",
            bpm: 120,
            bpmMatchScore: bpmMatchScore,
            energyMatchScore: energyMatchScore,
            familiarityScore: familiarityScore,
            historicalEffectScore: historicalEffectScore,
            contextAlignmentScore: contextAlignmentScore,
            recencyPenalty: recencyPenalty,
            timeOfDayScore: timeOfDayScore,
            finalScore: finalScore,
            confidence: confidence,
            explanationComponents: explanationComponents
        )
    }
}
