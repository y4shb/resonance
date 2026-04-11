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
        ScrollView {
            VStack(spacing: 16) {
                defaultsSection
                crossfadeSection
                transitionsSection
                sleepWindDownSection
                commuteSection
            }
            .padding()
        }
        .background(ResonanceColors.panelBg)
        .navigationTitle("My Sessions")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Defaults Section

    private var defaultsSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SESSION DEFAULTS")
                    .retroEngravedLabel()

                // Stepper replacement: RetroPushButton pair + RetroLCDPanel
                HStack(spacing: 12) {
                    RetroPushButton(label: "\u{2212}", icon: "minus") {
                        preferences.defaultSessionDuration = max(5, preferences.defaultSessionDuration - 5)
                        onSave()
                    }

                    RetroLCDPanel {
                        Text("\(preferences.defaultSessionDuration) MIN")
                            .font(RetroTypography.ledDigit)
                            .padding(8)
                    }

                    RetroPushButton(label: "+", icon: "plus") {
                        preferences.defaultSessionDuration = min(480, preferences.defaultSessionDuration + 5)
                        onSave()
                    }
                }

                // Intent picker: too many options for segmented, keep as Picker
                Picker("Default Intent", selection: $preferences.defaultSessionIntent) {
                    ForEach(SessionIntent.allCases) { intent in
                        Label(intent.rawValue, systemImage: intent.icon)
                            .tag(intent.rawValue)
                    }
                }
                .onChange(of: preferences.defaultSessionIntent) { _, _ in
                    onSave()
                }

                Text("Pre-selected values when you start a new listening session. You can always change them at session start.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    // MARK: - Crossfade Section

    private var crossfadeSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("CROSSFADE")
                    .retroEngravedLabel()

                HStack {
                    Text("Crossfade Enabled")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.crossfadeEnabled,
                        label: ""
                    )
                }
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

                        RetroSliderPot(
                            value: Binding(
                                get: { (preferences.crossfadeDuration - 1) / 9 },
                                set: { preferences.crossfadeDuration = 1 + $0 * 9; onSave() }
                            ),
                            orientation: .horizontal,
                            label: String(format: "%.1fs", preferences.crossfadeDuration),
                            length: 200
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Biometric Crossfade")
                            Spacer()
                            RetroToggleSwitch(
                                isOn: $preferences.biometricCrossfadeEnabled,
                                label: ""
                            )
                        }
                        .onChange(of: preferences.biometricCrossfadeEnabled) { _, _ in
                            onSave()
                        }

                        Text("Adjusts crossfade duration in real time based on heart rate and HRV.")
                            .font(RetroTypography.lcdCaption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if preferences.crossfadeEnabled {
                    Text("Biometric crossfade shortens transitions when your heart rate is elevated and extends them during rest.")
                        .font(RetroTypography.lcdCaption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Crossfade blends the end of one song into the beginning of the next for seamless listening.")
                        .font(RetroTypography.lcdCaption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Transitions Section

    private var transitionsSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("TRANSITIONS")
                    .retroEngravedLabel()

                HStack {
                    Text("Smooth Transitions")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.enableSmoothTransitions,
                        label: ""
                    )
                }
                .onChange(of: preferences.enableSmoothTransitions) { _, _ in
                    onSave()
                }

                Text("When enabled, the AI avoids jarring BPM or energy jumps between consecutive songs.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    // MARK: - Sleep Wind-Down (E7)

    private var sleepWindDownSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SLEEP WIND-DOWN")
                    .retroEngravedLabel()

                HStack {
                    Text("Auto-Detect Bedtime")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.sleepWindDownAutoDetect,
                        label: ""
                    )
                }
                .onChange(of: preferences.sleepWindDownAutoDetect) { _, _ in
                    onSave()
                }

                if preferences.sleepWindDownAutoDetect {
                    RetroSegmentedSelector(
                        selection: $preferences.sleepWindDownVolumeFadeDuration,
                        options: [5, 10, 15, 20, 30],
                        label: { "\($0)M" }
                    )
                    .onChange(of: preferences.sleepWindDownVolumeFadeDuration) { _, _ in
                        onSave()
                    }
                }

                Text("Automatically detects when you're winding down for sleep and gradually lowers volume and shifts to calmer music.")
                    .font(RetroTypography.lcdCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }

    // MARK: - Commute (E10)

    private var commuteSection: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 12) {
                Text("COMMUTE")
                    .retroEngravedLabel()

                HStack {
                    Text("CarPlay Auto-Commute")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.carPlayAutoCommute,
                        label: ""
                    )
                }
                .onChange(of: preferences.carPlayAutoCommute) { _, _ in
                    onSave()
                }

                HStack {
                    Text("Drowsiness Detection")
                    Spacer()
                    RetroToggleSwitch(
                        isOn: $preferences.drowsinessDetectionEnabled,
                        label: ""
                    )
                }
                .onChange(of: preferences.drowsinessDetectionEnabled) { _, _ in
                    onSave()
                }

                Text("When connected to CarPlay, automatically starts a commute-optimized session. Drowsiness detection uses biometrics to shift to more energizing music when it senses you're getting drowsy.")
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
        SessionSettingsView(
            preferences: .constant(UserPreferences.load()),
            onSave: { }
        )
    }
}
