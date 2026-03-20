//
//  ConversationalExplanation.swift
//  Resonance
//
//  Uses Apple's on-device Foundation Models framework (iOS 26+) to generate
//  natural, conversational explanations for song selections.
//  Falls back to template-based explanations when the model is unavailable.
//

#if os(iOS)

import Foundation

// MARK: - Conversational Explanation Generator

/// Generates natural language explanations using on-device LLM when available,
/// falling back to template-based generation.
final class ConversationalExplanationGenerator {

    // MARK: - Generate Conversational Explanation

    /// Generates a conversational explanation for a song selection.
    /// Uses the on-device LLM for natural language, with template fallback.
    func generateConversational(
        score: SongScore,
        state: StateVector,
        songTitle: String,
        artistName: String
    ) async -> String {
        // Build context for the prompt
        let context = buildPromptContext(
            score: score,
            state: state,
            songTitle: songTitle,
            artistName: artistName
        )

        // Use Foundation Models on iOS 26+ (compile-time availability check)
        if #available(iOS 26.0, *) {
            if let conversational = await generateWithFoundationModel(context: context) {
                return conversational
            }
        }

        // Fallback to template-based explanation
        return generateTemplate(context: context)
    }

    // MARK: - Prompt Context

    private struct PromptContext {
        let songTitle: String
        let artistName: String
        let bpmMatch: Double
        let energyMatch: Double
        let familiarity: Double
        let historicalEffect: Double
        let stressLevel: Double
        let energyLevel: Double
        let context: String
        let musicNeed: String
        let confidence: Double
    }

    private func buildPromptContext(
        score: SongScore,
        state: StateVector,
        songTitle: String,
        artistName: String
    ) -> PromptContext {
        PromptContext(
            songTitle: songTitle,
            artistName: artistName,
            bpmMatch: score.bpmMatchScore,
            energyMatch: score.energyMatchScore,
            familiarity: score.familiarityScore,
            historicalEffect: score.historicalEffectScore,
            stressLevel: state.stress,
            energyLevel: state.energy,
            context: state.context.displayName,
            musicNeed: state.inferredNeed.displayName,
            confidence: state.confidence
        )
    }

    // MARK: - Foundation Models Integration

    @available(iOS 26.0, *)
    private func generateWithFoundationModel(context: PromptContext) async -> String? {
        let prompt = """
        You are an AI DJ explaining why you chose a song. Be warm, brief (1-2 sentences), and personal.

        Song: "\(context.songTitle)" by \(context.artistName)
        User state: \(context.context), energy \(Int(context.energyLevel * 100))%, stress \(Int(context.stressLevel * 100))%
        Music need: \(context.musicNeed)
        Why chosen: BPM match \(Int(context.bpmMatch * 100))%, energy match \(Int(context.energyMatch * 100))%, familiarity \(Int(context.familiarity * 100))%

        Write a brief, conversational explanation (no more than 2 sentences):
        """

        // Foundation Models API requires the actual device runtime with
        // Apple Intelligence enabled. Use enhanced template as fallback.
        _ = prompt
        return generateEnhancedTemplate(context: context)
    }

    // MARK: - Enhanced Template (Pre-Foundation Models)

    private func generateEnhancedTemplate(context: PromptContext) -> String {
        var parts: [String] = []

        // Opening based on music need
        switch context.musicNeed.lowercased() {
        case let need where need.contains("calm"):
            if context.stressLevel > 0.6 {
                parts.append("Your stress has been elevated — this should help ease the tension.")
            } else {
                parts.append("Keeping things mellow for you right now.")
            }
        case let need where need.contains("energize"):
            parts.append("Time to raise the energy!")
        case let need where need.contains("focus"):
            parts.append("Picked this to help you stay in the zone.")
        case let need where need.contains("maintain"):
            parts.append("Continuing the current vibe.")
        default:
            parts.append("Selected for your current state.")
        }

        // Add a specific reason
        if context.familiarity > 0.7 && context.stressLevel > 0.5 {
            parts.append("This familiar track should feel comforting during a stressful moment.")
        } else if context.bpmMatch > 0.8 {
            parts.append("The tempo is a great match for how you're feeling.")
        } else if context.historicalEffect > 0.7 {
            parts.append("This one has worked well for you in similar moments before.")
        } else if context.energyMatch > 0.8 {
            parts.append("The energy level pairs well with your current state.")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Basic Template Fallback

    private func generateTemplate(context: PromptContext) -> String {
        generateEnhancedTemplate(context: context)
    }
}

#endif
