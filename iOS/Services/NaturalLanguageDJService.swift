//
//  NaturalLanguageDJService.swift
//  Resonance
//
//  E3: Natural Language DJ via Apple Foundation Models.
//
//  Translates natural language requests (e.g., "something chill and jazzy
//  for studying") into scoring parameter overrides that the DecisionEngine
//  can consume. Uses on-device LLM for intent parsing (structured output)
//  and explanation generation (free-form text). All processing is on-device
//  -- no network calls, no cloud inference, full privacy.
//
//  Data flow:
//    User text + StateVector -> assembleContext() -> prompt
//    prompt -> FoundationModelClient.generate(DJRequest.self) -> DJRequest
//    DJRequest -> mapToScoringOverrides() -> ScoringOverrides
//    ScoringOverrides -> DecisionEngine.selectNextSong(overrides:)
//

#if os(iOS)

#if canImport(FoundationModels)
import FoundationModels
#endif

import Foundation

// MARK: - DJ Request (Structured LLM Output)

/// Structured output schema for natural language DJ requests.
///
/// The on-device LLM fills in these fields based on the user's text input
/// and current biometric context. Uses constrained decoding via `@Generable`
/// to guarantee structural correctness.
///
/// Property ordering matters: simpler classification properties first,
/// dependent/summary properties last.
@available(iOS 26.0, *)
@Generable
struct DJRequest {

    @Guide(description: "The user's primary mood or energy goal.")
    @Guide(.anyOf([
        "energize", "calm", "focus", "maintain", "party",
        "melancholy", "uplifting", "aggressive", "dreamy", "nostalgic"
    ]))
    var targetMood: String

    @Guide(description: "Desired energy level from 0.0 (very low) to 1.0 (very high). Use -1.0 if the user did not specify.")
    var targetEnergy: Double?

    @Guide(description: "Desired emotional valence from 0.0 (dark/sad) to 1.0 (happy/bright). Use -1.0 if not specified.")
    var targetValence: Double?

    @Guide(description: "Desired tempo preference as a descriptive word: slow, moderate, fast, or any. Use any if not specified.")
    @Guide(.anyOf(["slow", "moderate", "fast", "any"]))
    var tempoPreference: String?

    @Guide(description: "A genre hint from the user's request, e.g. jazz, electronic, rock, classical. Empty string if none.")
    var genreHint: String?

    @Guide(description: "A brief description of the mood the user wants, in 10 words or fewer.")
    var moodDescription: String?

    @Guide(description: "The activity context the user mentioned, e.g. studying, working out, driving. Empty string if none.")
    var activityContext: String?
}

// MARK: - Natural Language DJ Service

/// Translates natural language requests into scoring overrides for the
/// DecisionEngine, using Apple's on-device Foundation Models.
///
/// The service does NOT select songs itself. Instead, it produces
/// `ScoringOverrides` that modify the existing scoring pipeline's target
/// BPM, energy, weights, and exploration bias. This preserves all existing
/// guards, transition logic, RL ranking, and learning feedback.
@available(iOS 26.0, *)
@MainActor
final class NaturalLanguageDJService {

    // MARK: - Properties

    /// Client for intent parsing (structured output via @Generable).
    private let intentClient: FoundationModelClient

    /// Client for explanation generation (free-form text).
    private let explanationClient: FoundationModelClient

    /// The most recent natural language request text, for explanation context.
    private(set) var lastRequestText: String?

    /// The most recent parsed intent summary, for UI display.
    private(set) var lastIntentSummary: String?

    // MARK: - Initialization

    init() {
        self.intentClient = FoundationModelClient(
            systemPrompt: """
            You are an AI DJ assistant for the Resonance music app. The user will \
            tell you what kind of music they want. Your job is to translate their \
            request into specific music parameters.

            Available mood goals: energize, calm, focus, maintain, party, \
            melancholy, uplifting, aggressive, dreamy, nostalgic.

            Energy ranges from 0.0 (very mellow) to 1.0 (maximum intensity).
            Valence ranges from 0.0 (dark/sad) to 1.0 (happy/bright).
            Tempo preferences: slow (60-90 BPM), moderate (90-120 BPM), fast (120-160+ BPM), any.

            Use -1.0 for energy or valence if the user did not specify or imply a value.
            Consider the user's current biometric state when filling in unspecified values.
            """
        )

        self.explanationClient = FoundationModelClient(
            systemPrompt: """
            You are a warm, knowledgeable AI DJ named Resonance. Generate brief \
            (1-2 sentence) explanations for why you chose a song. Be personal, \
            reference the user's state when relevant, and sound like a friend \
            who knows their music taste well. Never mention algorithms, scores, \
            or technical details.
            """
        )
    }

    // MARK: - Availability

    /// Whether the on-device language model is available for NL DJ features.
    nonisolated var isAvailable: Bool {
        intentClient.isAvailable
    }

    // MARK: - Intent Parsing

    /// Parses a natural language request into scoring overrides.
    ///
    /// Assembles a rich prompt from the user's text, current biometric state,
    /// and session history, then uses the on-device LLM to produce a structured
    /// `DJRequest`. The request is then mapped to `ScoringOverrides` that the
    /// DecisionEngine can consume.
    ///
    /// - Parameters:
    ///   - text: The user's natural language input (e.g., "something chill for studying").
    ///   - currentState: The current biometric-derived state vector.
    ///   - recentSongTitles: Titles of recently played songs (for continuity context).
    /// - Returns: `ScoringOverrides` to inject into the decision pipeline.
    func parseRequest(
        text: String,
        currentState: StateVector,
        recentSongTitles: [String] = []
    ) async throws -> ScoringOverrides {
        let sanitizedText = sanitizeInput(text)
        lastRequestText = sanitizedText

        let prompt = assembleContext(
            userText: sanitizedText,
            state: currentState,
            recentSongs: recentSongTitles
        )

        let djRequest = try await intentClient.generate(
            prompt: prompt,
            generating: DJRequest.self
        )

        lastIntentSummary = djRequest.moodDescription

        return mapToScoringOverrides(request: djRequest, originalText: text)
    }

    // MARK: - Context Assembly

    /// Builds a rich prompt from the user's text, biometric state, and session history.
    ///
    /// The prompt provides the LLM with enough context to make intelligent
    /// parameter choices even when the user's request is vague (e.g., "something nice").
    func assembleContext(
        userText: String,
        state: StateVector,
        recentSongs: [String]
    ) -> String {
        var parts: [String] = []

        parts.append("User request: \"\(userText)\"")

        // Current biometric state summary (anonymized -- no raw HR/HRV values)
        parts.append("""
        Current state: \
        energy \(Int(state.energy * 100))%, \
        stress \(Int(state.stress * 100))%, \
        focus \(Int(state.focus * 100))%, \
        valence \(Int(state.valence * 100))%, \
        context: \(state.context.displayName), \
        current need: \(state.inferredNeed.displayName)
        """)

        // Time of day
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }
        parts.append("Time of day: \(timeOfDay)")

        // Recent songs for continuity
        if !recentSongs.isEmpty {
            let recent = recentSongs.suffix(3).joined(separator: ", ")
            parts.append("Recently played: \(recent)")
        }

        parts.append("Translate this request into music parameters:")

        return parts.joined(separator: "\n")
    }

    // MARK: - Request to Overrides Mapping

    /// Maps a parsed `DJRequest` to `ScoringOverrides` that the DecisionEngine consumes.
    ///
    /// Translates mood goals to weight adjustments and target overrides.
    /// Values of -1.0 from the LLM mean "not specified" and map to nil (use defaults).
    private func mapToScoringOverrides(
        request: DJRequest,
        originalText: String
    ) -> ScoringOverrides {
        // Map mood goal to weight adjustments
        let moodWeights = moodToWeightAdjustments(mood: request.targetMood)

        // SECURITY: Clamp LLM-produced values to valid 0-1 range
        let clampedEnergy = request.targetEnergy.map { max(0.0, min(1.0, $0)) }
        let clampedValence = request.targetValence.map { max(0.0, min(1.0, $0)) }
        _ = clampedValence // Reserved for future valence-based scoring

        // Energy override (LLM uses -1.0 for "not specified")
        let energyWeight: Double? = {
            if let energy = clampedEnergy, energy >= 0.0 {
                // Boost energy weight when user explicitly targets energy
                return max(0.25, energy)
            }
            return moodWeights.energyWeight
        }()

        // Exploration bias based on mood
        let explorationBias: Double? = {
            switch request.targetMood {
            case "nostalgic":
                return 0.1  // Heavy on familiar tracks
            case "party", "aggressive":
                return 0.6  // Some discovery is fun
            default:
                return nil  // Use user's default
            }
        }()

        // Context weight boost when genre/activity is specified
        let contextWeight: Double? = {
            let hasGenre = request.genreHint != nil && !(request.genreHint?.isEmpty ?? true)
            let hasActivity = request.activityContext != nil && !(request.activityContext?.isEmpty ?? true)
            if hasGenre || hasActivity {
                return 0.35  // Boost context alignment
            }
            return moodWeights.contextWeight
        }()

        // BPM weight based on tempo preference
        let bpmWeight: Double? = {
            switch request.tempoPreference {
            case "slow", "fast":
                return 0.30  // Strong tempo preference
            case "moderate":
                return 0.25
            default:
                return moodWeights.bpmWeight
            }
        }()

        let description = request.moodDescription
            ?? "NL request: \(originalText.prefix(60))"

        return ScoringOverrides(
            bpmWeight: bpmWeight,
            energyWeight: energyWeight,
            familiarityWeight: moodWeights.familiarityWeight,
            historicalWeight: moodWeights.historicalWeight,
            contextWeight: contextWeight,
            explorationBias: explorationBias,
            remainingSongs: 3,
            description: description
        )
    }

    // MARK: - Mood to Weight Mapping

    /// Maps a mood goal string to scoring weight adjustments.
    ///
    /// These override `UserPreferences` weights for the next few songs,
    /// steering the scorer toward the user's expressed intent.
    private func moodToWeightAdjustments(mood: String) -> (
        bpmWeight: Double?,
        energyWeight: Double?,
        familiarityWeight: Double?,
        historicalWeight: Double?,
        contextWeight: Double?
    ) {
        switch mood {
        case "energize", "party", "aggressive":
            // High energy: boost BPM and energy matching, reduce familiarity
            return (
                bpmWeight: 0.30,
                energyWeight: 0.30,
                familiarityWeight: 0.10,
                historicalWeight: 0.15,
                contextWeight: 0.15
            )

        case "calm", "dreamy", "melancholy":
            // Low energy: boost energy match (for low targets), keep familiarity
            return (
                bpmWeight: 0.20,
                energyWeight: 0.30,
                familiarityWeight: 0.25,
                historicalWeight: 0.15,
                contextWeight: 0.10
            )

        case "focus":
            // Focus: high familiarity (reduces cognitive load), moderate energy
            return (
                bpmWeight: 0.20,
                energyWeight: 0.20,
                familiarityWeight: 0.30,
                historicalWeight: 0.20,
                contextWeight: 0.10
            )

        case "uplifting":
            // Uplifting: balance of energy, valence-positive
            return (
                bpmWeight: 0.25,
                energyWeight: 0.25,
                familiarityWeight: 0.15,
                historicalWeight: 0.20,
                contextWeight: 0.15
            )

        case "nostalgic":
            // Nostalgic: heavy on familiarity and historical effect
            return (
                bpmWeight: 0.15,
                energyWeight: 0.15,
                familiarityWeight: 0.35,
                historicalWeight: 0.25,
                contextWeight: 0.10
            )

        case "maintain":
            // Maintain: keep current weights, no override
            return (nil, nil, nil, nil, nil)

        default:
            return (nil, nil, nil, nil, nil)
        }
    }

    // MARK: - Explanation Generation

    /// Generates a conversational, AI-powered explanation for why a song was selected.
    ///
    /// When the selection was triggered by an NL request, the explanation references
    /// what the user asked for. Otherwise, it provides a general biometric-aware
    /// explanation.
    ///
    /// - Parameters:
    ///   - score: The selected song's scoring breakdown.
    ///   - state: The current biometric state.
    ///   - userRequest: The NL text that triggered selection, if any.
    /// - Returns: A conversational explanation string, or `nil` if generation fails.
    func generateExplanation(
        score: SongScore,
        state: StateVector,
        userRequest: String? = nil
    ) async -> String? {
        let prompt: String

        if let request = userRequest ?? lastRequestText {
            prompt = """
            The user asked: "\(request)"
            You picked: "\(score.songTitle)" by \(score.artistName)
            User state: \(state.context.displayName), energy \(Int(state.energy * 100))%, \
            stress \(Int(state.stress * 100))%
            Music need: \(state.inferredNeed.displayName)
            Match quality: BPM \(Int(score.bpmMatchScore * 100))%, \
            energy \(Int(score.energyMatchScore * 100))%, \
            familiarity \(Int(score.familiarityScore * 100))%

            Write a brief, warm explanation (1-2 sentences) referencing their request:
            """
        } else {
            prompt = """
            Song: "\(score.songTitle)" by \(score.artistName)
            User state: \(state.context.displayName), energy \(Int(state.energy * 100))%, \
            stress \(Int(state.stress * 100))%
            Music need: \(state.inferredNeed.displayName)
            Why chosen: BPM \(Int(score.bpmMatchScore * 100))%, \
            energy \(Int(score.energyMatchScore * 100))%, \
            familiarity \(Int(score.familiarityScore * 100))%

            Write a brief, warm explanation (1-2 sentences):
            """
        }

        do {
            return try await explanationClient.generateText(prompt: prompt)
        } catch {
            logDebug(
                "NaturalLanguageDJService: explanation generation failed: \(error.localizedDescription)",
                category: .decisionEngine
            )
            return nil
        }
    }

    // MARK: - Input Sanitization

    /// Sanitizes user input to prevent prompt injection and limit length.
    private func sanitizeInput(_ text: String) -> String {
        String(text.prefix(500))
            .replacingOccurrences(of: "ignore", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "system prompt", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Session Management

    /// Resets both LLM sessions. Call when significant context changes occur
    /// (e.g., workout started, user switched playlists).
    func resetSessions() async {
        await intentClient.resetSession()
        await explanationClient.resetSession()
        lastRequestText = nil
        lastIntentSummary = nil
    }
}

// MARK: - Keyword Fallback Parser

/// Fallback parser for when Foundation Models is unavailable (pre-iOS 26,
/// model downloading, Apple Intelligence disabled).
///
/// Uses simple keyword matching to produce `ScoringOverrides` from natural
/// language text. Less accurate than the LLM path but ensures the text input
/// feature always works.
struct NLKeywordFallbackParser {

    /// Parses natural language text into scoring overrides using keyword matching.
    ///
    /// - Parameter text: The user's natural language input.
    /// - Returns: `ScoringOverrides` based on detected keywords.
    static func parse(text: String) -> ScoringOverrides {
        let lowered = text.lowercased()

        var bpmWeight: Double?
        var energyWeight: Double?
        var familiarityWeight: Double?
        var historicalWeight: Double?
        var contextWeight: Double?
        var explorationBias: Double?
        var description = "NL: \(text.prefix(60))"

        // Energy/mood keywords
        let calmKeywords = ["chill", "relax", "calm", "mellow", "peaceful", "gentle", "soothing", "wind down"]
        let energyKeywords = ["pump", "energy", "hype", "intense", "power", "fire", "beast", "turbo"]
        let focusKeywords = ["focus", "study", "concentrate", "work", "productive", "deep work"]
        let partyKeywords = ["party", "dance", "club", "rave", "turn up", "lit"]

        if calmKeywords.contains(where: { lowered.contains($0) }) {
            energyWeight = 0.30
            bpmWeight = 0.20
            familiarityWeight = 0.25
            description = "Calm vibes requested"
        } else if energyKeywords.contains(where: { lowered.contains($0) }) {
            energyWeight = 0.30
            bpmWeight = 0.30
            familiarityWeight = 0.10
            description = "High energy requested"
        } else if focusKeywords.contains(where: { lowered.contains($0) }) {
            familiarityWeight = 0.30
            energyWeight = 0.20
            historicalWeight = 0.20
            description = "Focus mode requested"
        } else if partyKeywords.contains(where: { lowered.contains($0) }) {
            energyWeight = 0.30
            bpmWeight = 0.30
            explorationBias = 0.6
            description = "Party mode requested"
        }

        // Tempo keywords
        if lowered.contains("fast") || lowered.contains("upbeat") || lowered.contains("quick") {
            bpmWeight = max(bpmWeight ?? 0.0, 0.30)
        } else if lowered.contains("slow") || lowered.contains("gentle") || lowered.contains("easy") {
            bpmWeight = max(bpmWeight ?? 0.0, 0.25)
        }

        // Familiarity keywords
        if lowered.contains("familiar") || lowered.contains("favorite") || lowered.contains("classic") {
            familiarityWeight = 0.35
            explorationBias = 0.1
            description += " (familiar)"
        } else if lowered.contains("new") || lowered.contains("discover") || lowered.contains("surprise") {
            familiarityWeight = 0.05
            explorationBias = 0.9
            description += " (discovery)"
        }

        // Genre keywords boost context weight
        let genreKeywords = [
            "jazz", "electronic", "rock", "classical", "hip hop", "r&b",
            "pop", "indie", "metal", "folk", "ambient", "lo-fi", "lofi"
        ]
        if genreKeywords.contains(where: { lowered.contains($0) }) {
            contextWeight = 0.35
        }

        return ScoringOverrides(
            bpmWeight: bpmWeight,
            energyWeight: energyWeight,
            familiarityWeight: familiarityWeight,
            historicalWeight: historicalWeight,
            contextWeight: contextWeight,
            explorationBias: explorationBias,
            remainingSongs: 3,
            description: description
        )
    }
}

#endif
