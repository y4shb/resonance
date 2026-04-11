//
//  AISettingsView.swift
//  Resonance
//
//  "My AI" settings: exploration bias, body-vs-mind weighting,
//  DJ autonomy, explanation verbosity, and advanced weight tuning.
//

import SwiftUI

// MARK: - AI Settings View

struct AISettingsView: View {
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                explorationSection
                influenceSection
                autonomySection
                verbositySection
                commentarySection
                emotionalSupportSection
                weatherInfluenceSection
                advancedSection
            }
            .padding()
        }
        .background(ResonanceColors.panelBg)
        .navigationTitle("My AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Exploration Bias

    private var explorationSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("DISCOVERY")
                    .retroEngravedLabel()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Exploration Bias")
                            .font(.subheadline)
                        Spacer()
                        Text(explorationLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    RetroSliderPot(
                        value: $preferences.explorationBias,
                        orientation: .horizontal,
                        label: explorationLabel,
                        length: 200
                    )
                    .onChange(of: preferences.explorationBias) { _, _ in
                        onSave()
                    }

                    HStack {
                        Text("Familiar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Adventurous")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("How willing the AI is to play songs you haven't heard recently or tracks outside your usual taste.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    private var explorationLabel: String {
        switch preferences.explorationBias {
        case 0..<0.2: return "Very Familiar"
        case 0.2..<0.4: return "Mostly Familiar"
        case 0.4..<0.6: return "Balanced"
        case 0.6..<0.8: return "Exploratory"
        default: return "Very Adventurous"
        }
    }

    // MARK: - Body vs Mind Influence

    private var influenceSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("INFLUENCE BALANCE")
                    .retroEngravedLabel()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Body vs Mind")
                            .font(.subheadline)
                        Spacer()
                        Text(influenceLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    RetroSliderPot(
                        value: $preferences.bodyVsMindWeight,
                        orientation: .horizontal,
                        label: influenceLabel,
                        length: 200
                    )
                    .onChange(of: preferences.bodyVsMindWeight) { _, _ in
                        onSave()
                    }

                    HStack {
                        Text("Mood Input")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Biometrics")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Whether the AI weighs your stated mood or your biometric signals more when choosing songs.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    private var influenceLabel: String {
        switch preferences.bodyVsMindWeight {
        case 0..<0.3: return "Mood-Driven"
        case 0.3..<0.7: return "Balanced"
        default: return "Body-Driven"
        }
    }

    // MARK: - DJ Autonomy

    private var autonomySection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("AUTONOMY")
                    .retroEngravedLabel()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DJ Autonomy")
                            .font(.subheadline)
                        Spacer()
                        Text(autonomyLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    RetroSliderPot(
                        value: $preferences.djAutonomy,
                        orientation: .horizontal,
                        label: autonomyLabel,
                        length: 200
                    )
                    .onChange(of: preferences.djAutonomy) { _, _ in
                        onSave()
                    }

                    HStack {
                        Text("Manual")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Fully Autonomous")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("How independently the AI acts. Lower values mean more user confirmation; higher values let the AI make more decisions on its own.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    private var autonomyLabel: String {
        switch preferences.djAutonomy {
        case 0..<0.3: return "Co-pilot"
        case 0.3..<0.7: return "Guided"
        default: return "Autonomous"
        }
    }

    // MARK: - Verbosity

    private var verbositySection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("EXPLANATIONS")
                    .retroEngravedLabel()

                RetroSegmentedSelector(
                    selection: $preferences.aiVerbosity,
                    options: [0, 1, 2],
                    label: { ["SILENT", "MINIMAL", "DETAILED"][$0] }
                )
                .onChange(of: preferences.aiVerbosity) { _, _ in
                    onSave()
                }

                Text("How much the AI explains its song choices. \"Silent\" hides all reasoning; \"Detailed\" shows full decision context.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    // MARK: - DJ Commentary (E8)

    private var commentarySection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("DJ COMMENTARY")
                    .retroEngravedLabel()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Frequency")
                        .font(.subheadline)

                    RetroSegmentedSelector(
                        selection: $preferences.commentaryFrequency,
                        options: ["everyTrack", "everyThird", "significantOnly", "off"],
                        label: {
                            switch $0 {
                            case "everyTrack": return "EVERY"
                            case "everyThird": return "3RD"
                            case "significantOnly": return "KEY"
                            case "off": return "OFF"
                            default: return $0.uppercased()
                            }
                        }
                    )
                    .onChange(of: preferences.commentaryFrequency) { _, _ in
                        onSave()
                    }
                }

                HStack {
                    Text("Voice Commentary")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.commentaryVoiceEnabled,
                        label: ""
                    )
                }
                .onChange(of: preferences.commentaryVoiceEnabled) { _, _ in
                    onSave()
                }

                Text("The AI DJ can share short insights about why it chose a song or how the music relates to your current state.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    // MARK: - Emotional Support (E5/E6)

    private var emotionalSupportSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("EMOTIONAL SUPPORT")
                    .retroEngravedLabel()

                HStack {
                    Text("Anxiety Interception")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.anxietyInterceptionEnabled,
                        label: ""
                    )
                }
                .onChange(of: preferences.anxietyInterceptionEnabled) { _, _ in
                    onSave()
                }

                if preferences.anxietyInterceptionEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Sensitivity")
                                .font(.subheadline)
                            Spacer()
                            Text(anxietySensitivityLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        RetroSliderPot(
                            value: $preferences.anxietyInterceptionSensitivity,
                            orientation: .horizontal,
                            label: anxietySensitivityLabel,
                            length: 200
                        )
                        .onChange(of: preferences.anxietyInterceptionSensitivity) { _, _ in
                            onSave()
                        }
                    }
                }

                HStack {
                    Text("Emotional Regulation")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.emotionalRegulationEnabled,
                        label: ""
                    )
                }
                .onChange(of: preferences.emotionalRegulationEnabled) { _, _ in
                    onSave()
                }

                Text("When enabled, the AI detects elevated stress through biometrics and gently shifts music to help you regulate. Emotional regulation uses a gradual \"ladder\" approach rather than abrupt changes.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    private var anxietySensitivityLabel: String {
        switch preferences.anxietyInterceptionSensitivity {
        case 0..<0.3: return "Low"
        case 0.3..<0.7: return "Medium"
        default: return "High"
        }
    }

    // MARK: - Weather Influence (E9)

    private var weatherInfluenceSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("WEATHER INFLUENCE")
                    .retroEngravedLabel()

                HStack {
                    Text("Weather Influence")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.weatherInfluenceEnabled,
                        label: ""
                    )
                }
                .onChange(of: preferences.weatherInfluenceEnabled) { _, _ in
                    onSave()
                }

                if preferences.weatherInfluenceEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Influence Weight")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(preferences.weatherInfluenceWeight * 100))%")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        RetroSliderPot(
                            value: Binding(
                                get: { min(1.0, preferences.weatherInfluenceWeight / 0.5) },
                                set: { preferences.weatherInfluenceWeight = $0 * 0.5; onSave() }
                            ),
                            orientation: .horizontal,
                            label: "\(Int(preferences.weatherInfluenceWeight * 100))%",
                            length: 200
                        )

                        HStack {
                            Text("Subtle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Strong")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Lets the AI factor in current weather conditions when selecting music. Rainy days might bring mellower tracks; sunny days, upbeat energy.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("ADVANCED")
                    .retroEngravedLabel()

                NavigationLink {
                    DJTuningView(preferences: $preferences, onSave: onSave)
                } label: {
                    BrushedMetalSurface(cornerRadius: 8) {
                        HStack {
                            Label("Advanced Weight Tuning", systemImage: "slider.horizontal.3")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(ResonanceColors.metalMid)
                        }
                        .padding(12)
                    }
                }
                .buttonStyle(.plain)

                Text("Fine-tune individual ranking weights, behavioral rules, and time-of-day constraints.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AISettingsView(
            preferences: .constant(UserPreferences.load()),
            onSave: { }
        )
    }
}
