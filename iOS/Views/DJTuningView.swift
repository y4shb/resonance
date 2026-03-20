//
//  DJTuningView.swift
//  Resonance
//
//  Advanced settings for ranking weights, behavioral preferences, and time-of-day rules.
//  Navigated to from the main SettingsView under "Advanced > DJ Tuning".
//

import SwiftUI

// MARK: - DJ Tuning View

/// Advanced settings for ranking weights, behavioral preferences, and time-of-day rules.
struct DJTuningView: View {
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    var body: some View {
        List {
            rankingWeightsSection
            behavioralPreferencesSection
            timeOfDaySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("DJ Tuning")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Weight Sum Indicator

    private var weightSum: Int {
        Int((preferences.bpmWeight
            + preferences.energyWeight
            + preferences.familiarityWeight
            + preferences.historicalWeight
            + preferences.contextWeight) * 100)
    }

    private var weightSumColor: Color {
        switch weightSum {
        case 95...105: return .green
        case 80...120: return .yellow
        default: return .red
        }
    }

    // MARK: - Ranking Weights Section

    private var rankingWeightsSection: some View {
        Section {
            HStack {
                Text("Total:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(weightSum)%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(weightSumColor)
                    .monospacedDigit()
            }
            .padding(.vertical, 2)

            weightSlider(label: "BPM Match", value: $preferences.bpmWeight)
            weightSlider(label: "Energy Level", value: $preferences.energyWeight)
            weightSlider(label: "Familiarity", value: $preferences.familiarityWeight)
            weightSlider(label: "Historical", value: $preferences.historicalWeight)
            weightSlider(label: "Context", value: $preferences.contextWeight)

            Button("Normalize Weights") {
                preferences.normalizeWeights()
                onSave()
            }

            HStack(spacing: 12) {
                Button("Focus") {
                    preferences = .focusPreset
                    onSave()
                }
                .buttonStyle(.bordered)

                Button("Workout") {
                    preferences = .workoutPreset
                    onSave()
                }
                .buttonStyle(.bordered)

                Button("Relaxation") {
                    preferences = .relaxationPreset
                    onSave()
                }
                .buttonStyle(.bordered)
            }

            Button("Reset to Defaults") {
                preferences = .default
                onSave()
            }
            .foregroundStyle(.red)
        } header: {
            Text("Ranking Weights")
        } footer: {
            Text("Adjust how different factors influence song selection. Weights should sum to 100%. Use Normalize to rebalance.")
        }
    }

    private func weightSlider(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0.0...1.0, step: 0.01) { editing in
                if !editing {
                    onSave()
                }
            }
            .accessibilityLabel("\(label) weight")
            .accessibilityValue("\(Int(value.wrappedValue * 100)) percent")
        }
    }

    // MARK: - Behavioral Preferences Section

    private var behavioralPreferencesSection: some View {
        Section {
            Stepper(
                "Avoid Recent: \(preferences.avoidRecentMinutes) min",
                value: $preferences.avoidRecentMinutes,
                in: 0...480,
                step: 15
            ) { editing in
                if !editing {
                    onSave()
                }
            }

            Stepper(
                "Max Same Artist in Row: \(preferences.maxSameArtistInRow)",
                value: $preferences.maxSameArtistInRow,
                in: 1...10
            ) { editing in
                if !editing {
                    onSave()
                }
            }

            Toggle("Prefer Familiar in Stress", isOn: $preferences.preferFamiliarInStress)
                .onChange(of: preferences.preferFamiliarInStress) { _, _ in
                    onSave()
                }

            Toggle("Enable Smooth Transitions", isOn: $preferences.enableSmoothTransitions)
                .onChange(of: preferences.enableSmoothTransitions) { _, _ in
                    onSave()
                }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Allow Cross-Playlist Recommendations", isOn: $preferences.allowCrossPlaylistRecommendations)
                    .onChange(of: preferences.allowCrossPlaylistRecommendations) { _, _ in
                        onSave()
                    }

                Text("Let the AI DJ pick songs from other playlists when they fit your mood")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Behavioral Preferences")
        } footer: {
            Text("Control playback behavior such as song repetition avoidance and artist variety.")
        }
    }

    // MARK: - Time of Day Section

    private var timeOfDaySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Morning Max BPM")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(preferences.morningMaxBPM))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $preferences.morningMaxBPM, in: 60...200, step: 5) { editing in
                    if !editing {
                        onSave()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Night Max BPM")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(preferences.nightMaxBPM))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $preferences.nightMaxBPM, in: 40...200, step: 5) { editing in
                    if !editing {
                        onSave()
                    }
                }
            }

            Picker("Morning Ends At", selection: $preferences.morningEndHour) {
                ForEach(5...12, id: \.self) { hour in
                    Text("\(hour):00").tag(hour)
                }
            }
            .onChange(of: preferences.morningEndHour) { _, _ in
                onSave()
            }

            Picker("Night Starts At", selection: $preferences.nightStartHour) {
                ForEach(18...23, id: \.self) { hour in
                    Text("\(hour):00").tag(hour)
                }
            }
            .onChange(of: preferences.nightStartHour) { _, _ in
                onSave()
            }
        } header: {
            Text("Time-of-Day Rules")
        } footer: {
            Text("Limit BPM during morning and evening hours for gentler music at appropriate times.")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DJTuningView(
            preferences: .constant(UserPreferences.load()),
            onSave: { }
        )
    }
}
