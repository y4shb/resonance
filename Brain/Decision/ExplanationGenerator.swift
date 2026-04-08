//
//  ExplanationGenerator.swift
//  Resonance
//
//  Generates human-readable explanations for why a song was selected.
//  Produces both a full explanation for the iOS UI and a shorter version for Watch.
//

#if os(iOS)

import Foundation

// MARK: - Song Explanation

/// Human-readable explanation for why a song was selected.
struct SongExplanation: Sendable {
    /// Full explanation string for iOS display.
    let full: String

    /// Short explanation for Watch (max ~40 chars).
    let short: String

    /// The top contributing factors, sorted by importance.
    let factors: [ExplanationFactor]

    /// Description of the current user state.
    let stateDescription: String

    /// Description of the inferred music need.
    let needDescription: String
}

/// A single factor contributing to the song selection.
struct ExplanationFactor: Sendable, Identifiable {
    let id = UUID()

    /// Human-readable name of the factor.
    let name: String

    /// How much this factor contributed (0.0 - 1.0).
    let contribution: Double

    /// Short description of this factor's impact.
    let description: String
}

// MARK: - Explanation Generator

/// Generates human-readable explanations for song selections.
final class ExplanationGenerator {

    // MARK: - Generate Explanation

    /// Generates a full explanation for the selected song.
    func generate(
        score: SongScore,
        state: StateVector,
        isSessionStart: Bool
    ) -> SongExplanation {
        let factors = buildFactors(score: score, state: state)
        let stateDescription = describeState(state)
        let needDescription = describeNeed(state.inferredNeed)

        let full = buildFullExplanation(
            score: score,
            factors: factors,
            stateDescription: stateDescription,
            needDescription: needDescription,
            isSessionStart: isSessionStart
        )

        let short = buildShortExplanation(
            score: score,
            state: state
        )

        return SongExplanation(
            full: full,
            short: short,
            factors: factors,
            stateDescription: stateDescription,
            needDescription: needDescription
        )
    }

    // MARK: - Factor Building

    /// Builds a sorted list of factors that contributed to the selection.
    private func buildFactors(score: SongScore, state: StateVector) -> [ExplanationFactor] {
        var factors: [ExplanationFactor] = []

        // BPM match
        if score.bpm > 0 {
            let description: String
            if score.bpmMatchScore > 0.8 {
                description = "BPM closely matches target (\(Int(score.bpm)) BPM)"
            } else if score.bpmMatchScore > 0.4 {
                description = "BPM is near target (\(Int(score.bpm)) BPM)"
            } else {
                description = "BPM differs from target (\(Int(score.bpm)) BPM)"
            }
            factors.append(ExplanationFactor(
                name: "Tempo",
                contribution: score.bpmMatchScore,
                description: description
            ))
        }

        // Energy match
        let energyDescription: String
        if score.energyMatchScore > 0.85 {
            energyDescription = "Energy level is a great fit"
        } else if score.energyMatchScore > 0.7 {
            energyDescription = "Energy level is a good match"
        } else {
            energyDescription = "Energy level is moderate match"
        }
        factors.append(ExplanationFactor(
            name: "Energy",
            contribution: score.energyMatchScore,
            description: energyDescription
        ))

        // Historical effect
        if score.historicalEffectScore != 0.5 {
            let effectDescription: String
            if score.historicalEffectScore > 0.7 {
                effectDescription = "Historically effective for \(state.inferredNeed.displayName.lowercased())"
            } else if score.historicalEffectScore > 0.5 {
                effectDescription = "Has shown positive effects before"
            } else {
                effectDescription = "Historical data is mixed"
            }
            factors.append(ExplanationFactor(
                name: "History",
                contribution: score.historicalEffectScore,
                description: effectDescription
            ))
        }

        // Context alignment
        let contextDescription = "Fits \(state.context.displayName.lowercased()) context"
        factors.append(ExplanationFactor(
            name: "Context",
            contribution: score.contextAlignmentScore,
            description: contextDescription
        ))

        // Familiarity
        if score.familiarityScore > 0.3 {
            let familiarityDescription: String
            if state.stress > 0.6 {
                familiarityDescription = "Familiar track (comforting during stress)"
            } else if state.inferredNeed == .focus {
                familiarityDescription = "Familiar track (helps maintain focus)"
            } else {
                familiarityDescription = "Known track in your library"
            }
            factors.append(ExplanationFactor(
                name: "Familiarity",
                contribution: score.familiarityScore,
                description: familiarityDescription
            ))
        }

        // Sort by contribution descending
        return factors.sorted { $0.contribution > $1.contribution }
    }

    // MARK: - State Description

    /// Describes the current user state in natural language.
    private func describeState(_ state: StateVector) -> String {
        var parts: [String] = []

        // Energy level
        if state.energy > 0.7 {
            parts.append("high energy")
        } else if state.energy < 0.3 {
            parts.append("low energy")
        }

        // Stress
        if state.stress > 0.6 {
            parts.append("elevated stress")
        } else if state.stress < 0.3 {
            parts.append("relaxed")
        }

        // Focus
        if state.focus > 0.7 {
            parts.append("deep focus")
        }

        // Context
        if state.context != .unknown {
            parts.append(state.context.displayName.lowercased())
        }

        if parts.isEmpty {
            return "Balanced state"
        }

        let result = parts.joined(separator: ", ")
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    /// Describes the inferred music need.
    private func describeNeed(_ need: MusicNeed) -> String {
        switch need {
        case .energize:
            return "Looking for music to boost your energy"
        case .calm:
            return "Looking for music to help you relax"
        case .focus:
            return "Looking for music to support concentration"
        case .maintain:
            return "Keeping the current vibe going"
        case .transition:
            return "Smoothly transitioning to a new state"
        }
    }

    // MARK: - Full Explanation

    /// Builds the full explanation string for iOS display.
    private func buildFullExplanation(
        score: SongScore,
        factors: [ExplanationFactor],
        stateDescription: String,
        needDescription: String,
        isSessionStart: Bool
    ) -> String {
        var lines: [String] = []

        // Opening line based on need
        if isSessionStart {
            lines.append("Starting your session with this track.")
        }
        lines.append(needDescription + ".")

        // Top factors (max 3)
        let topFactors = factors.prefix(3)
        for factor in topFactors {
            lines.append("• \(factor.description)")
        }

        return lines.joined(separator: " ")
    }

    // MARK: - Short Explanation (Watch)

    /// Builds a short explanation for Watch display (~40 chars max).
    private func buildShortExplanation(
        score: SongScore,
        state: StateVector
    ) -> String {
        // Pick the primary reason based on the top-scoring component
        let components: [(String, Double)] = [
            ("Great tempo match", score.bpmMatchScore),
            ("Energy fit", score.energyMatchScore),
            ("Known favorite", score.familiarityScore),
            ("Proven effective", score.historicalEffectScore),
            ("Fits your context", score.contextAlignmentScore)
        ]

        // Find the top component
        if let top = components.max(by: { $0.1 < $1.1 }) {
            let needPrefix: String
            switch state.inferredNeed {
            case .energize: needPrefix = "To energize"
            case .calm: needPrefix = "To relax"
            case .focus: needPrefix = "For focus"
            case .maintain: needPrefix = "Continuing"
            case .transition: needPrefix = "Transitioning"
            }

            return "\(needPrefix): \(top.0.lowercased())"
        }

        return state.inferredNeed.description
    }
}

#endif
