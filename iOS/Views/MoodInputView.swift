//
//  MoodInputView.swift
//  Resonance
//
//  Manual mood input with energy and valence sliders.
//  Values are passed to StateEngine for blending into StateVector.
//  Input decays over 15 minutes.
//

import SwiftUI

struct MoodInputView: View {
    @ObservedObject var stateEngine: StateEngine

    @State private var energy = 0.5
    @State private var valence = 0.5
    @State private var hasSubmitted = false
    @State private var hasInitializedFromState = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 6) {
                    Text("How are you feeling?")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("This helps Resonance match songs to your current state")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // Dynamic color indicator responding to slider positions
                moodColorIndicator
                    .padding(.horizontal)

                // Energy slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Energy")
                            .font(.headline)
                        Spacer()
                        Text(energyLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $energy, in: 0...1, step: 0.05) {
                        Text("Energy")
                    } minimumValueLabel: {
                        Text("Low")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("High")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tint(.orange)
                    .accessibilityLabel("Energy level")
                    .accessibilityValue(energyLabel)
                    .accessibilityHint("Adjust your current energy level from low to high")
                }
                .padding(.horizontal)

                // Mood/Valence slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Mood")
                            .font(.headline)
                        Spacer()
                        Text(moodLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $valence, in: 0...1, step: 0.05) {
                        Text("Mood")
                    } minimumValueLabel: {
                        Text("Down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("Great")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tint(ResonanceColors.accent)
                    .accessibilityLabel("Mood level")
                    .accessibilityValue(moodLabel)
                    .accessibilityHint("Adjust your current mood from down to great")
                }
                .padding(.horizontal)

                // Music suggestion preview
                Text(musicSuggestionPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                // Submit button
                Button {
                    stateEngine.setManualMood(energy: energy, valence: valence)
                    hasSubmitted = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: hasSubmitted ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                        Text(hasSubmitted ? "Updated" : "Set Mood")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasSubmitted ? Color.green : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .disabled(hasSubmitted)
                .accessibilityLabel(hasSubmitted ? "Mood updated" : "Set mood")
                .accessibilityHint(hasSubmitted ? "Mood has been submitted" : "Submit your current energy and mood levels")
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Mood Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if !hasInitializedFromState {
                    hasInitializedFromState = true
                    if let mood = stateEngine.manualMood, mood.isActive {
                        energy = mood.energy
                        valence = mood.valence
                    } else {
                        energy = stateEngine.currentState.energy
                        valence = stateEngine.currentState.valence
                    }
                }
            }
        }
    }

    // MARK: - Dynamic Color Indicator

    /// A rounded rectangle that blends energy and mood colors
    /// to give real-time visual feedback as the user adjusts sliders.
    private var moodColorIndicator: some View {
        let energyColor = Color(
            hue: 0.08 + energy * 0.05,
            saturation: 0.5 + energy * 0.4,
            brightness: 0.7 + energy * 0.2
        )
        let valenceColor = Color(
            hue: 0.55 + valence * 0.12,
            saturation: 0.4 + valence * 0.3,
            brightness: 0.6 + valence * 0.3
        )

        return HStack(spacing: 0) {
            energyColor
            valenceColor
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .animation(.easeOut(duration: 0.2), value: energy)
        .animation(.easeOut(duration: 0.2), value: valence)
        .accessibilityHidden(true)
    }

    // MARK: - Music Suggestion Preview

    private var musicSuggestionPreview: String {
        switch (energy, valence) {
        case (0..<0.35, 0..<0.35):
            return "Resonance will look for calm, mellow tracks"
        case (0..<0.35, 0.35..<0.65):
            return "Resonance will look for gentle, easy-going tracks"
        case (0..<0.35, 0.65...1.0):
            return "Resonance will look for soft, uplifting tracks"
        case (0.35..<0.65, 0..<0.35):
            return "Resonance will look for moderate, reflective tracks"
        case (0.35..<0.65, 0.35..<0.65):
            return "Resonance will pick balanced, versatile tracks"
        case (0.35..<0.65, 0.65...1.0):
            return "Resonance will look for feel-good, groovy tracks"
        case (0.65...1.0, 0..<0.35):
            return "Resonance will look for intense, driving tracks"
        case (0.65...1.0, 0.35..<0.65):
            return "Resonance will look for energetic, upbeat tracks"
        case (0.65...1.0, 0.65...1.0):
            return "Resonance will look for high-energy, euphoric tracks"
        default:
            return "Resonance will match songs to how you feel"
        }
    }

    // MARK: - Labels

    private var energyLabel: String {
        switch energy {
        case 0..<0.2: return "Exhausted"
        case 0.2..<0.4: return "Tired"
        case 0.4..<0.6: return "Moderate"
        case 0.6..<0.8: return "Energetic"
        default: return "Pumped"
        }
    }

    private var moodLabel: String {
        switch valence {
        case 0..<0.2: return "Low"
        case 0.2..<0.4: return "Down"
        case 0.4..<0.6: return "Neutral"
        case 0.6..<0.8: return "Good"
        default: return "Great"
        }
    }
}

#Preview {
    MoodInputView(
        stateEngine: StateEngine(
            contextCollector: ContextCollector(),
            healthKitService: HealthKitService()
        )
    )
}
