//
//  FocusModeIntents.swift
//  Resonance
//
//  Focus Mode Filter integration via App Intents framework.
//  Automatically adjusts session mode when iOS Focus Mode changes.
//

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
        // Apply the session preset via UserDefaults
        // The StateEngine reads these on its next 30-second update cycle
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        defaults?.set(sessionPreset.rawValue, forKey: "focusFilter.activePreset")
        defaults?.set(maxBPM, forKey: "focusFilter.maxBPM")
        defaults?.set(preferFamiliar, forKey: "focusFilter.preferFamiliar")
        defaults?.set(true, forKey: "focusFilter.isActive")
        defaults?.synchronize()

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
        defaults?.synchronize()

        return .result(dialog: "Starting \(sessionType.rawValue) session in Resonance.")
    }
}
