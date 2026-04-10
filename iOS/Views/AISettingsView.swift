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
        List {
            explorationSection
            influenceSection
            autonomySection
            verbositySection
            commentarySection
            emotionalSupportSection
            weatherInfluenceSection
            advancedSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Exploration Bias

    private var explorationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Exploration Bias")
                        .font(.subheadline)
                    Spacer()
                    Text(explorationLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $preferences.explorationBias, in: 0...1, step: 0.05) { editing in
                    if !editing { onSave() }
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
        } header: {
            Text("Discovery")
        } footer: {
            Text("How willing the AI is to play songs you haven't heard recently or tracks outside your usual taste.")
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
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Body vs Mind")
                        .font(.subheadline)
                    Spacer()
                    Text(influenceLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $preferences.bodyVsMindWeight, in: 0...1, step: 0.05) { editing in
                    if !editing { onSave() }
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
        } header: {
            Text("Influence Balance")
        } footer: {
            Text("Whether the AI weighs your stated mood or your biometric signals more when choosing songs.")
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
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DJ Autonomy")
                        .font(.subheadline)
                    Spacer()
                    Text(autonomyLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $preferences.djAutonomy, in: 0...1, step: 0.1) { editing in
                    if !editing { onSave() }
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
        } header: {
            Text("Autonomy")
        } footer: {
            Text("How independently the AI acts. Lower values mean more user confirmation; higher values let the AI make more decisions on its own.")
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
        Section {
            Picker("AI Explanations", selection: $preferences.aiVerbosity) {
                Text("Silent").tag(0)
                Text("Minimal").tag(1)
                Text("Detailed").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: preferences.aiVerbosity) { _, _ in
                onSave()
            }
        } header: {
            Text("Explanations")
        } footer: {
            Text("How much the AI explains its song choices. \"Silent\" hides all reasoning; \"Detailed\" shows full decision context.")
        }
    }

    // MARK: - DJ Commentary (E8)

    private var commentarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Frequency")
                    .font(.subheadline)

                Picker("Commentary Frequency", selection: $preferences.commentaryFrequency) {
                    Text("Every Track").tag("everyTrack")
                    Text("Every 3rd").tag("everyThird")
                    Text("Significant").tag("significantOnly")
                    Text("Off").tag("off")
                }
                .pickerStyle(.segmented)
                .onChange(of: preferences.commentaryFrequency) { _, _ in
                    onSave()
                }
            }

            Toggle("Voice Commentary", isOn: $preferences.commentaryVoiceEnabled)
                .onChange(of: preferences.commentaryVoiceEnabled) { _, _ in
                    onSave()
                }
        } header: {
            Text("DJ Commentary")
        } footer: {
            Text("The AI DJ can share short insights about why it chose a song or how the music relates to your current state.")
        }
    }

    // MARK: - Emotional Support (E5/E6)

    private var emotionalSupportSection: some View {
        Section {
            Toggle("Anxiety Interception", isOn: $preferences.anxietyInterceptionEnabled)
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

                    Slider(
                        value: $preferences.anxietyInterceptionSensitivity,
                        in: 0...1,
                        step: 0.1
                    ) { editing in
                        if !editing { onSave() }
                    }
                }
            }

            Toggle("Emotional Regulation", isOn: $preferences.emotionalRegulationEnabled)
                .onChange(of: preferences.emotionalRegulationEnabled) { _, _ in
                    onSave()
                }
        } header: {
            Text("Emotional Support")
        } footer: {
            Text("When enabled, the AI detects elevated stress through biometrics and gently shifts music to help you regulate. Emotional regulation uses a gradual \"ladder\" approach rather than abrupt changes.")
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
        Section {
            Toggle("Weather Influence", isOn: $preferences.weatherInfluenceEnabled)
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

                    Slider(
                        value: $preferences.weatherInfluenceWeight,
                        in: 0...0.5,
                        step: 0.05
                    ) { editing in
                        if !editing { onSave() }
                    }

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
        } header: {
            Text("Weather Influence")
        } footer: {
            Text("Lets the AI factor in current weather conditions when selecting music. Rainy days might bring mellower tracks; sunny days, upbeat energy.")
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        Section {
            NavigationLink {
                DJTuningView(preferences: $preferences, onSave: onSave)
            } label: {
                Label("Advanced Weight Tuning", systemImage: "slider.horizontal.3")
            }
        } header: {
            Text("Advanced")
        } footer: {
            Text("Fine-tune individual ranking weights, behavioral rules, and time-of-day constraints.")
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
