//
//  DJCommentaryService.swift
//  Resonance
//
//  Generates brief AI DJ commentary at track transitions, providing
//  a narrative about the listener's journey. Uses Apple Foundation Models
//  (iOS 26+) when available, with template-based fallback for older devices.
//
//  Part of E8: AI DJ Commentary via Foundation Models.
//

#if os(iOS)

import Foundation
import AVFoundation

// MARK: - Commentary Frequency

/// How often the AI DJ generates commentary at track transitions.
enum CommentaryFrequency: String, Codable, CaseIterable, Sendable {
    case everyTrack
    case everyThird
    case significantOnly
    case off
}

// MARK: - DJ Commentary

/// A single piece of DJ commentary generated at a track transition.
struct DJCommentary: Sendable {
    let text: String
    let timestamp: Date
    let isSignificant: Bool
    let trackTitle: String
}

// MARK: - Notable Event

/// Events during a session that warrant commentary in significantOnly mode.
enum NotableEvent: Sendable {
    case stressShift(delta: Double)
    case contextChange(from: ActivityContext, to: ActivityContext)
    case sessionMilestone(count: Int)
    case energyReversal
    case firstSongOfSession
    case moodShift(delta: Double)
    case recoveryDetected
}

// MARK: - Trend Direction

/// Direction of biometric trends between tracks.
enum TrendDirection: String, Sendable {
    case rising
    case falling
    case stable
}

// MARK: - Commentary Context

/// All context needed to generate one DJ commentary.
struct CommentaryContext: Sendable {
    let previousTrackTitle: String?
    let previousTrackArtist: String?
    let previousTrackBPM: Double?

    let currentTrackTitle: String
    let currentTrackArtist: String
    let currentTrackBPM: Double

    // SECURITY: Raw biometric values replaced with categorical to prevent leakage
    let heartRateCategory: String  // "elevated", "normal", or "low"
    let stress: Double
    let energy: Double
    let arousal: Double

    let trendDirection: TrendDirection
    let activityContext: ActivityContext
    let musicNeed: MusicNeed
    let sessionSongsPlayed: Int
    let sessionDurationMinutes: Double
    let notableEvents: [NotableEvent]
}

// MARK: - DJ Commentary Service

/// Generates brief AI DJ commentary at track transitions. Determines whether
/// commentary should fire based on user frequency settings, assembles context,
/// and generates text via Foundation Models or template fallback.
@MainActor
final class DJCommentaryService {

    // MARK: - Properties

    private var speechSynthesizer: AVSpeechSynthesizer?
    private(set) var isSpeaking = false
    private var speechDelegate: SpeechDelegate?

    // MARK: - Frequency Gating

    /// Determines whether commentary should be generated for this transition.
    func shouldGenerateCommentary(
        frequency: CommentaryFrequency,
        trackNumber: Int,
        notableEvents: [NotableEvent]
    ) -> Bool {
        switch frequency {
        case .off:
            return false
        case .everyTrack:
            return true
        case .everyThird:
            return trackNumber % 3 == 0 || trackNumber == 1
        case .significantOnly:
            return !notableEvents.isEmpty
        }
    }

    // MARK: - Notable Event Detection

    /// Detects notable events by comparing current and previous states.
    func detectNotableEvents(
        currentState: StateVector,
        previousState: StateVector?,
        sessionSongCount: Int,
        isSessionStart: Bool
    ) -> [NotableEvent] {
        var events: [NotableEvent] = []

        if isSessionStart {
            events.append(.firstSongOfSession)
            return events
        }

        guard let previous = previousState else { return events }

        // Stress shift (delta > 0.2)
        let stressDelta = currentState.stress - previous.stress
        if abs(stressDelta) > 0.2 {
            events.append(.stressShift(delta: stressDelta))
        }

        // Context change
        if currentState.context != previous.context,
           currentState.context != .unknown,
           previous.context != .unknown {
            events.append(.contextChange(from: previous.context, to: currentState.context))
        }

        // Session milestones
        let milestones = [10, 25, 50, 100]
        if milestones.contains(sessionSongCount) {
            events.append(.sessionMilestone(count: sessionSongCount))
        }

        // Energy reversal
        let energyDelta = currentState.energy - previous.energy
        if abs(energyDelta) > 0.15 {
            events.append(.energyReversal)
        }

        // Mood shift (valence)
        let valenceDelta = currentState.valence - previous.valence
        if abs(valenceDelta) > 0.25 {
            events.append(.moodShift(delta: valenceDelta))
        }

        // Recovery: stress dropping from elevated (>0.6) to low (<0.35)
        if previous.stress > 0.6 && currentState.stress < 0.35 {
            events.append(.recoveryDetected)
        }

        return events
    }

    // MARK: - Context Assembly

    /// Builds a structured context for commentary generation from available data.
    func assembleContext(
        previousDecision: DecisionResult?,
        currentScore: SongScore,
        currentState: StateVector,
        previousState: StateVector?,
        biometric: BiometricSignal?,
        sessionSongsPlayed: Int,
        sessionStartDate: Date,
        notableEvents: [NotableEvent]
    ) -> CommentaryContext {
        // Determine trend direction from energy
        let trendDirection: TrendDirection
        if let previous = previousState {
            let delta = currentState.energy - previous.energy
            if delta > 0.1 {
                trendDirection = .rising
            } else if delta < -0.1 {
                trendDirection = .falling
            } else {
                trendDirection = .stable
            }
        } else {
            trendDirection = .stable
        }

        let durationMinutes = Date().timeIntervalSince(sessionStartDate) / 60.0

        // SECURITY: Categorize raw biometrics instead of forwarding values
        let hrCategory: String = {
            guard let hr = biometric?.heartRate else { return "normal" }
            if hr > 100 { return "elevated" }
            if hr < 55 { return "low" }
            return "normal"
        }()

        return CommentaryContext(
            previousTrackTitle: previousDecision?.score.songTitle,
            previousTrackArtist: previousDecision?.score.artistName,
            previousTrackBPM: previousDecision?.score.bpm,
            currentTrackTitle: currentScore.songTitle,
            currentTrackArtist: currentScore.artistName,
            currentTrackBPM: currentScore.bpm,
            heartRateCategory: hrCategory,
            stress: currentState.stress,
            energy: currentState.energy,
            arousal: currentState.arousal,
            trendDirection: trendDirection,
            activityContext: currentState.context,
            musicNeed: currentState.inferredNeed,
            sessionSongsPlayed: sessionSongsPlayed,
            sessionDurationMinutes: durationMinutes,
            notableEvents: notableEvents
        )
    }

    // MARK: - Commentary Generation

    /// Generates DJ commentary for a track transition. Uses Foundation Models
    /// on iOS 26+, falling back to templates on older devices.
    func generateCommentary(context: CommentaryContext) async -> DJCommentary? {
        let isSignificant = !context.notableEvents.isEmpty

        // Try Foundation Models on iOS 26+
        if #available(iOS 26.0, *) {
            if let text = await generateWithFoundationModel(context: context) {
                logDebug("Generated FM commentary: \(text)", category: .decisionEngine)
                return DJCommentary(
                    text: text,
                    timestamp: Date(),
                    isSignificant: isSignificant,
                    trackTitle: context.currentTrackTitle
                )
            }
        }

        // Fallback: template-based commentary
        let text = generateTemplateCommentary(context: context)
        logDebug("Generated template commentary: \(text)", category: .decisionEngine)
        return DJCommentary(
            text: text,
            timestamp: Date(),
            isSignificant: isSignificant,
            trackTitle: context.currentTrackTitle
        )
    }

    // MARK: - Foundation Models Generation

    @available(iOS 26.0, *)
    private func generateWithFoundationModel(context: CommentaryContext) async -> String? {
        let prompt = buildFoundationModelPrompt(context: context)

        // Foundation Models API requires Apple Intelligence runtime.
        // Currently falls back to enhanced template. When Apple Intelligence
        // is available on-device, replace this with:
        //
        //   import FoundationModels
        //   let session = LanguageModelSession()
        //   let response = try await session.respond(to: prompt)
        //   return response.content
        //
        _ = prompt
        return generateEnhancedTemplate(context: context)
    }

    /// Builds the Foundation Model prompt from context.
    private func buildFoundationModelPrompt(context: CommentaryContext) -> String {
        var prompt = """
        You are a warm, insightful AI DJ commenting on a track transition.
        Be brief (1-2 sentences max). Sound natural, like a real DJ.

        """

        if let prevTitle = context.previousTrackTitle,
           let prevArtist = context.previousTrackArtist,
           let prevBPM = context.previousTrackBPM {
            prompt += """
            Previous track: "\(prevTitle)" by \(prevArtist) (\(Int(prevBPM)) BPM)

            """
        }

        prompt += """
        New track: "\(context.currentTrackTitle)" by \(context.currentTrackArtist) (\(Int(context.currentTrackBPM)) BPM)
        Listener state: \(context.activityContext.displayName), energy \(Int(context.energy * 100))%, stress \(Int(context.stress * 100))%
        Trend: energy has been \(context.trendDirection.rawValue)
        Session: \(context.sessionSongsPlayed) tracks over \(Int(context.sessionDurationMinutes)) minutes

        """

        // Add notable events
        for event in context.notableEvents {
            switch event {
            case .stressShift(let delta):
                let direction = delta > 0 ? "rising" : "dropping"
                prompt += "Notable: stress is \(direction)\n"
            case .contextChange(let from, let to):
                prompt += "Notable: activity changed from \(from.displayName) to \(to.displayName)\n"
            case .sessionMilestone(let count):
                prompt += "Notable: \(count) tracks played this session\n"
            case .energyReversal:
                prompt += "Notable: energy trend just reversed\n"
            case .firstSongOfSession:
                prompt += "Notable: this is the first song of the session\n"
            case .moodShift(let delta):
                let direction = delta > 0 ? "improving" : "dipping"
                prompt += "Notable: mood is \(direction)\n"
            case .recoveryDetected:
                prompt += "Notable: stress has dropped significantly -- recovery detected\n"
            }
        }

        prompt += "\nComment on the transition naturally:"
        return prompt
    }

    // MARK: - Enhanced Template (FM-like quality)

    /// Generates a richer template commentary that approximates Foundation Model quality.
    private func generateEnhancedTemplate(context: CommentaryContext) -> String {
        // Handle notable events first for more specific commentary
        for event in context.notableEvents {
            switch event {
            case .firstSongOfSession:
                return buildSessionStartTemplate(context: context)
            case .recoveryDetected:
                return "Your stress has eased -- \"\(context.currentTrackTitle)\" should keep that calm momentum going."
            case .stressShift(let delta) where delta > 0:
                return "Sensing some tension rising -- this track should help steady things."
            case .stressShift(let delta) where delta < -0.15:
                return "Nice, you're unwinding. \"\(context.currentTrackTitle)\" keeps that vibe going."
            case .contextChange(_, let to):
                return "Shifting gears for \(to.displayName.lowercased()) -- \"\(context.currentTrackTitle)\" fits the new pace."
            case .sessionMilestone(let count):
                return "\(count) tracks deep. \"\(context.currentTrackTitle)\" keeps the session rolling."
            case .moodShift(let delta) where delta > 0:
                return "Your mood is lifting -- riding that wave with \"\(context.currentTrackTitle)\"."
            case .energyReversal:
                return "Energy just shifted -- \"\(context.currentTrackTitle)\" matches the new direction."
            default:
                continue
            }
        }

        return buildTransitionTemplate(context: context)
    }

    /// Template for the first song of a session.
    private func buildSessionStartTemplate(context: CommentaryContext) -> String {
        switch context.musicNeed {
        case .energize:
            return "Kicking off with \"\(context.currentTrackTitle)\" to get your energy up."
        case .calm:
            return "Starting with something mellow -- \"\(context.currentTrackTitle)\" to ease you in."
        case .focus:
            return "Setting the focus tone with \"\(context.currentTrackTitle)\"."
        case .maintain:
            return "Here we go -- \"\(context.currentTrackTitle)\" to set the mood."
        case .transition:
            return "Starting your session with \"\(context.currentTrackTitle)\"."
        }
    }

    /// Template for standard track transitions.
    private func buildTransitionTemplate(context: CommentaryContext) -> String {
        // BPM-based transition commentary
        if let prevBPM = context.previousTrackBPM {
            let bpmDelta = context.currentTrackBPM - prevBPM
            if bpmDelta > 15 {
                return "Picking up the tempo with \"\(context.currentTrackTitle)\" -- \(Int(context.currentTrackBPM)) BPM."
            } else if bpmDelta < -15 {
                return "Easing into something slower with \"\(context.currentTrackTitle)\"."
            }
        }

        // Music need-based commentary
        switch context.musicNeed {
        case .calm:
            if context.stress > 0.6 {
                return "Your stress is elevated -- this should help ease the tension."
            } else {
                return "Keeping things mellow with \"\(context.currentTrackTitle)\"."
            }
        case .energize:
            return "Time to raise the energy -- \"\(context.currentTrackTitle)\" should do the trick."
        case .focus:
            return "Staying in the zone with \"\(context.currentTrackTitle)\"."
        case .maintain:
            return "Continuing the vibe with \"\(context.currentTrackTitle)\"."
        case .transition:
            return "Smoothly moving into \"\(context.currentTrackTitle)\"."
        }
    }

    // MARK: - Template Fallback (pre-iOS 26)

    /// Simple template-based commentary using ExplanationGenerator patterns.
    private func generateTemplateCommentary(context: CommentaryContext) -> String {
        generateEnhancedTemplate(context: context)
    }

    // MARK: - Voice Commentary (AVSpeechSynthesizer)

    /// Speaks the given commentary text, ducking music audio during speech.
    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        if speechSynthesizer == nil {
            speechSynthesizer = AVSpeechSynthesizer()
            speechDelegate = SpeechDelegate { [weak self] in
                self?.isSpeaking = false
                self?.restoreAudioSession()
            }
            speechSynthesizer?.delegate = speechDelegate
        }

        // Stop any in-progress speech
        if let synth = speechSynthesizer, synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }

        // Duck music audio
        configureAudioSessionForSpeech()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.3

        isSpeaking = true
        speechSynthesizer?.speak(utterance)
        logDebug("Speaking commentary: \(text)", category: .decisionEngine)
    }

    /// Stops in-progress speech immediately.
    func stopSpeaking() {
        speechSynthesizer?.stopSpeaking(at: .immediate)
        isSpeaking = false
        restoreAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSessionForSpeech() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                options: [.duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logWarning("Failed to configure audio session for speech: \(error.localizedDescription)", category: .decisionEngine)
        }
    }

    private func restoreAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logWarning("Failed to restore audio session after speech: \(error.localizedDescription)", category: .decisionEngine)
        }
    }
}

// MARK: - Speech Delegate

private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onFinish()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onFinish()
        }
    }
}

#endif
