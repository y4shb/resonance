//
//  FoundationModelClient.swift
//  Resonance
//
//  Shared infrastructure for Apple's on-device Foundation Models framework.
//  Provides thread-safe model session management with availability checks
//  and graceful fallback for pre-iOS 26 devices.
//
//  Used by E3 (Natural Language DJ) and E8 (future enhancements).
//

#if canImport(FoundationModels)
import FoundationModels
#endif

import Foundation

// MARK: - Foundation Model Client

/// Thread-safe client for Apple's on-device Foundation Models framework.
///
/// Manages `LanguageModelSession` instances with system prompts tailored to
/// the Resonance DJ context. All inference runs on-device via Apple Intelligence
/// -- no network calls, no API keys, full privacy.
///
/// Usage:
/// ```swift
/// let client = FoundationModelClient(systemPrompt: "You are an AI DJ.")
/// if client.isAvailable {
///     let result: MyStruct? = try await client.generate(
///         prompt: "Pick a mood",
///         generating: MyStruct.self
///     )
/// }
/// ```
@available(iOS 26.0, *)
actor FoundationModelClient {

    // MARK: - Properties

    /// The system-level instructions that shape the model's persona and behavior.
    private let systemPrompt: String

    /// Lazily-initialized language model session.
    /// Kept alive across requests for session context continuity.
    private var session: LanguageModelSession?

    // MARK: - Initialization

    /// Creates a new Foundation Model client with the given system prompt.
    ///
    /// - Parameter systemPrompt: Instructions that define the model's persona
    ///   and behavioral constraints. Set once at init; applies to all requests.
    init(systemPrompt: String) {
        self.systemPrompt = systemPrompt
    }

    // MARK: - Availability

    /// Whether the on-device language model is available for inference.
    ///
    /// Returns `false` when:
    /// - The device does not support Apple Intelligence (pre-A17 Pro)
    /// - The model is currently downloading or updating
    /// - Apple Intelligence is disabled in Settings
    nonisolated var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    // MARK: - Session Management

    /// Returns the active session, creating one if needed.
    private func getOrCreateSession() -> LanguageModelSession {
        if let existing = session {
            return existing
        }
        let newSession = LanguageModelSession(
            instructions: systemPrompt
        )
        session = newSession
        return newSession
    }

    /// Resets the current session, forcing a fresh one on the next request.
    /// Call this when the conversation context should not carry over
    /// (e.g., significant state change, new activity context).
    func resetSession() {
        session = nil
    }

    // MARK: - Generation (Structured Output)

    /// Generates a structured response conforming to the given `Generable` type.
    ///
    /// Uses constrained decoding to guarantee structural correctness of the output.
    /// The model fills in the fields of `T` based on the prompt and system instructions.
    ///
    /// - Parameters:
    ///   - prompt: The user-facing request text.
    ///   - type: The `Generable` type to produce (must have `@Generable` macro).
    /// - Returns: A populated instance of `T`, or `nil` if generation fails.
    func generate<T: Generable>(
        prompt: String,
        generating type: T.Type
    ) async throws -> T {
        let activeSession = getOrCreateSession()
        let response = try await activeSession.respond(
            to: prompt,
            generating: type
        )
        return response.content
    }

    // MARK: - Generation (Free-form Text)

    /// Generates a free-form text response from the model.
    ///
    /// Used for conversational explanations, summaries, and other
    /// unstructured text where `@Generable` is not needed.
    ///
    /// - Parameter prompt: The user-facing request text.
    /// - Returns: The model's text response, or `nil` if empty.
    func generateText(prompt: String) async throws -> String? {
        let activeSession = getOrCreateSession()
        let response = try await activeSession.respond(to: prompt)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

// MARK: - Pre-iOS 26 Fallback

/// Stub client for devices that do not support Foundation Models.
/// All generation methods return `nil`, allowing callers to fall back
/// to template-based or keyword-based approaches.
final class FoundationModelClientUnavailable: Sendable {

    /// Always returns `false`.
    var isAvailable: Bool { false }

    /// Always returns `nil`.
    func generate<T>(prompt: String, generating type: T.Type) async -> T? {
        nil
    }

    /// Always returns `nil`.
    func generateText(prompt: String) async -> String? {
        nil
    }
}
