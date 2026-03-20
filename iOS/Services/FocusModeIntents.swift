//
//  FocusModeIntents.swift
//  Resonance
//
//  Focus Mode Filter integration via App Intents framework.
//  Automatically adjusts session mode when iOS Focus Mode changes.
//

#if os(iOS)

import AppIntents

// MARK: - Focus Mode Session Preset

/// Represents the session preset that Resonance applies when a Focus Mode activates.
enum FocusSessionPreset: String, AppEnum {
    case deepWork = "Deep Work"
    case workout = "Workout"
    case relaxation = "Relaxation"
    case autoDetect = "Auto-Detect"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Session Preset")
    static var caseDisplayRepresentations: [FocusSessionPreset: DisplayRepresentation] = [
        .deepWork: "Deep Work",
        .workout: "Workout",
        .relaxation: "Relaxation",
        .autoDetect: "Auto-Detect",
    ]
}

// MARK: - Resonance Focus Filter

/// Focus Filter that activates when a specific iOS Focus Mode is enabled.
/// Users configure which session preset to use for each Focus Mode in Settings > Focus.
struct ResonanceFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Set Resonance Session"
    static var description: IntentDescription? = IntentDescription(
        "Configure how Resonance adapts music when this Focus Mode is active.",
        categoryName: "Music"
    )

    /// Display representation for the Focus Filter (required by InstanceDisplayRepresentable)
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Resonance: \(sessionPreset.rawValue)")
    }

    /// The session preset to apply when this Focus Mode activates.
    @Parameter(title: "Session Preset", default: .autoDetect)
    var sessionPreset: FocusSessionPreset

    /// The maximum BPM allowed during this Focus Mode (optional override).
    @Parameter(title: "Max BPM", default: 130)
    var maxBPM: Int

    /// Whether to prefer familiar songs (reduces cognitive load).
    @Parameter(title: "Prefer Familiar Songs", default: false)
    var preferFamiliar: Bool

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        defaults?.set(sessionPreset.rawValue, forKey: "focusFilter.activePreset")
        defaults?.set(maxBPM, forKey: "focusFilter.maxBPM")
        defaults?.set(preferFamiliar, forKey: "focusFilter.preferFamiliar")
        defaults?.set(true, forKey: "focusFilter.isActive")

        logInfo(
            "Focus Filter activated: preset=\(sessionPreset.rawValue), maxBPM=\(maxBPM), familiar=\(preferFamiliar)",
            category: .stateEngine
        )

        return .result()
    }
}

// MARK: - Start Session Intent (Siri / Shortcuts)

/// App Intent for starting a Resonance session via Siri or Shortcuts.
struct StartResonanceSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Resonance Session"
    static var description: IntentDescription? = IntentDescription(
        "Start playing music adapted to your current state.",
        categoryName: "Music"
    )

    @Parameter(title: "Session Type")
    var sessionType: FocusSessionPreset

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$sessionType) session")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        defaults?.set(sessionType.rawValue, forKey: "focusFilter.activePreset")
        defaults?.set(true, forKey: "focusFilter.isActive")

        return .result(dialog: "Starting \(sessionType.rawValue) session in Resonance.")
    }
}

// MARK: - Skip Track Intent (Siri / Shortcuts)

/// Siri intent to skip the current track.
struct SkipTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Song"
    static var description: IntentDescription? = IntentDescription(
        "Skip the currently playing song in Resonance.",
        categoryName: "Music"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        defaults?.set(true, forKey: "siri.skipRequested")
        return .result(dialog: "Skipping song in Resonance.")
    }
}

// MARK: - Get Current State Intent (Siri)

/// Siri intent to check current biometric state.
struct GetCurrentStateIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My State"
    static var description: IntentDescription? = IntentDescription(
        "Check your current biometric state in Resonance.",
        categoryName: "Health"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        let stateName = defaults?.string(forKey: "widget.state.stateName") ?? "Unknown"
        let energy = defaults?.double(forKey: "widget.state.energy") ?? 0.5
        let heartRate = defaults?.double(forKey: "widget.state.heartRate")

        var response = "Your current state is \(stateName) with \(Int(energy * 100))% energy."
        if let hr = heartRate, hr > 0 {
            response += " Heart rate: \(Int(hr)) BPM."
        }

        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - App Shortcuts Provider

/// Registers Resonance shortcuts for the Shortcuts app and Siri suggestions.
struct ResonanceShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartResonanceSessionIntent(),
            phrases: [
                "Start a \(\.$sessionType) session in \(.applicationName)",
                "Start \(.applicationName) in \(\.$sessionType) mode",
                "Play \(\.$sessionType) music in \(.applicationName)",
            ],
            shortTitle: "Start Session",
            systemImageName: "waveform.circle.fill"
        )

        AppShortcut(
            intent: SkipTrackIntent(),
            phrases: [
                "Skip song in \(.applicationName)",
                "Next song in \(.applicationName)",
            ],
            shortTitle: "Skip Song",
            systemImageName: "forward.fill"
        )

        AppShortcut(
            intent: GetCurrentStateIntent(),
            phrases: [
                "What's my state in \(.applicationName)",
                "How am I doing in \(.applicationName)",
                "Check my \(.applicationName) state",
            ],
            shortTitle: "Check State",
            systemImageName: "heart.fill"
        )
    }
}

#endif
