//
//  SessionSettingsView.swift
//  Resonance
//
//  "My Sessions" settings: default session duration, default intent,
//  crossfade configuration, and transition behavior.
//

import SwiftUI

// MARK: - Session Settings View

struct SessionSettingsView: View {
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    var body: some View {
        List {
            defaultsSection
            crossfadeSection
            transitionsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Sessions")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Defaults Section

    private var defaultsSection: some View {
        Section {
            Stepper(
                "Duration: \(preferences.defaultSessionDuration) min",
                value: $preferences.defaultSessionDuration,
                in: 5...480,
                step: 5
            ) { editing in
                if !editing { onSave() }
            }

            Picker("Default Intent", selection: $preferences.defaultSessionIntent) {
                ForEach(SessionIntent.allCases) { intent in
                    Label(intent.rawValue, systemImage: intent.icon)
                        .tag(intent.rawValue)
                }
            }
            .onChange(of: preferences.defaultSessionIntent) { _, _ in
                onSave()
            }
        } header: {
            Text("Session Defaults")
        } footer: {
            Text("Pre-selected values when you start a new listening session. You can always change them at session start.")
        }
    }

    // MARK: - Crossfade Section

    private var crossfadeSection: some View {
        Section {
            Toggle("Crossfade Enabled", isOn: $preferences.crossfadeEnabled)
                .onChange(of: preferences.crossfadeEnabled) { _, _ in
                    onSave()
                }

            if preferences.crossfadeEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Crossfade Duration")
                            .font(.subheadline)
                        Spacer()
                        Text("\(String(format: "%.1f", preferences.crossfadeDuration))s")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $preferences.crossfadeDuration,
                        in: 1...10,
                        step: 0.5
                    ) { editing in
                        if !editing { onSave() }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Biometric Crossfade", isOn: $preferences.biometricCrossfadeEnabled)
                        .onChange(of: preferences.biometricCrossfadeEnabled) { _, _ in
                            onSave()
                        }

                    Text("Adjusts crossfade duration in real time based on heart rate and HRV.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Crossfade")
        } footer: {
            if preferences.crossfadeEnabled {
                Text("Biometric crossfade shortens transitions when your heart rate is elevated and extends them during rest.")
            } else {
                Text("Crossfade blends the end of one song into the beginning of the next for seamless listening.")
            }
        }
    }

    // MARK: - Transitions Section

    private var transitionsSection: some View {
        Section {
            Toggle("Smooth Transitions", isOn: $preferences.enableSmoothTransitions)
                .onChange(of: preferences.enableSmoothTransitions) { _, _ in
                    onSave()
                }
        } header: {
            Text("Transitions")
        } footer: {
            Text("When enabled, the AI avoids jarring BPM or energy jumps between consecutive songs.")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionSettingsView(
            preferences: .constant(UserPreferences.load()),
            onSave: { }
        )
    }
}
