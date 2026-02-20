//
//  SongScore.swift
//  Resonance
//
//  Ranking result for a song candidate
//

import Foundation

/// Ranking result for a song candidate in the decision engine
public struct SongScore: Identifiable, Comparable, Sendable {
    public let id: UUID
    public let songId: UUID

    // MARK: - Song Info (for display)

    public let songTitle: String
    public let artistName: String
    public let albumName: String
    public let bpm: Double

    // MARK: - Component Scores (0.0 - 1.0)

    /// How well BPM matches desired energy level
    public let bpmMatchScore: Double

    /// How well song energy matches needed energy
    public let energyMatchScore: Double

    /// Familiarity bonus (known songs reduce cognitive load)
    public let familiarityScore: Double

    /// Historical effectiveness for current context
    public let historicalEffectScore: Double

    /// Alignment with current context (workout, focus, etc.)
    public let contextAlignmentScore: Double

    /// Recency penalty (avoid recently played)
    public let recencyPenalty: Double

    /// Time-of-day appropriateness
    public let timeOfDayScore: Double

    // MARK: - Final Score

    /// Weighted combination of all factors
    public let finalScore: Double

    /// Confidence in this score
    public let confidence: Double

    // MARK: - Explanation

    /// Human-readable explanation of why this song was selected
    public let explanationComponents: [ExplanationComponent]

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        songId: UUID,
        songTitle: String,
        artistName: String,
        albumName: String,
        bpm: Double,
        bpmMatchScore: Double,
        energyMatchScore: Double,
        familiarityScore: Double,
        historicalEffectScore: Double,
        contextAlignmentScore: Double,
        recencyPenalty: Double,
        timeOfDayScore: Double,
        finalScore: Double,
        confidence: Double,
        explanationComponents: [ExplanationComponent]
    ) {
        self.id = id
        self.songId = songId
        self.songTitle = songTitle
        self.artistName = artistName
        self.albumName = albumName
        self.bpm = bpm
        self.bpmMatchScore = bpmMatchScore
        self.energyMatchScore = energyMatchScore
        self.familiarityScore = familiarityScore
        self.historicalEffectScore = historicalEffectScore
        self.contextAlignmentScore = contextAlignmentScore
        self.recencyPenalty = recencyPenalty
        self.timeOfDayScore = timeOfDayScore
        self.finalScore = finalScore
        self.confidence = confidence
        self.explanationComponents = explanationComponents
    }

    // MARK: - Comparable

    public static func < (lhs: SongScore, rhs: SongScore) -> Bool {
        lhs.finalScore < rhs.finalScore
    }

    public static func == (lhs: SongScore, rhs: SongScore) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Explanation Component

public struct ExplanationComponent: Codable, Sendable, Identifiable {
    public let id: UUID
    public let factor: String
    public let contribution: Double
    public let description: String

    public init(
        id: UUID = UUID(),
        factor: String,
        contribution: Double,
        description: String
    ) {
        self.id = id
        self.factor = factor
        self.contribution = contribution
        self.description = description
    }
}

// MARK: - SongScore Extensions

extension SongScore {
    /// Returns a short explanation suitable for Watch display
    public var shortExplanation: String {
        guard let topComponent = explanationComponents.max(by: { $0.contribution < $1.contribution }) else {
            return "Selected for you"
        }
        return topComponent.description
    }

    /// Returns a full explanation for iOS display
    public var fullExplanation: String {
        let sortedComponents = explanationComponents.sorted { $0.contribution > $1.contribution }
        let topFactors = sortedComponents.prefix(3)

        let factorDescriptions = topFactors.map { component in
            "• \(component.description)"
        }.joined(separator: "\n")

        return "Why this song?\n\n\(factorDescriptions)"
    }

    /// Returns the score as a percentage string
    public var scorePercentage: String {
        "\(Int(finalScore * 100))%"
    }
}

// MARK: - Factory Methods

extension SongScore {
    /// Creates a placeholder score for testing
    public static func placeholder(
        songTitle: String = "Test Song",
        artistName: String = "Test Artist",
        score: Double = 0.8
    ) -> SongScore {
        SongScore(
            songId: UUID(),
            songTitle: songTitle,
            artistName: artistName,
            albumName: "Test Album",
            bpm: 120,
            bpmMatchScore: score,
            energyMatchScore: score,
            familiarityScore: score,
            historicalEffectScore: score,
            contextAlignmentScore: score,
            recencyPenalty: 0,
            timeOfDayScore: score,
            finalScore: score,
            confidence: 0.8,
            explanationComponents: [
                ExplanationComponent(
                    factor: "BPM Match",
                    contribution: 0.3,
                    description: "Tempo matches your current energy"
                )
            ]
        )
    }
}
