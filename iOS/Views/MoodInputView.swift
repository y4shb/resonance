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

    @State private var energy: Double = 0.5
    @State private var valence: Double = 0.5
    @State private var hasSubmitted = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("How are you feeling?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 16)

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
                    .tint(.blue)
                }
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(hasSubmitted)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Mood Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
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
