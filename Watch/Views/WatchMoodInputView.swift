//
//  WatchMoodInputView.swift
//  ResonanceWatch
//
//  Three-tap mood input for Apple Watch.
//  Two screens: energy level (3 options), then mood level (3 options).
//  Sends MoodPacket to iPhone via PhoneConnectivityService.
//

import SwiftUI
import WatchKit

struct WatchMoodInputView: View {
    let connectivityService: PhoneConnectivityService

    @State private var step: InputStep = .energy
    @State private var selectedEnergy: Int = 0
    @State private var selectedMood: Int = 0
    @State private var hasSubmitted = false

    @Environment(\.dismiss) private var dismiss

    enum InputStep {
        case energy
        case mood
        case confirmed
    }

    var body: some View {
        VStack {
            switch step {
            case .energy:
                energySelectionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            case .mood:
                moodSelectionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            case .confirmed:
                confirmationView
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .navigationTitle(step == .energy ? "Energy" : step == .mood ? "Mood" : "Done")
    }

    // MARK: - Energy Selection

    private var energySelectionView: some View {
        VStack(spacing: 12) {
            Text("Energy Level")
                .font(.headline)

            Button {
                selectedEnergy = 1
                WKInterfaceDevice.current().play(.click)
                step = .mood
            } label: {
                Label("Low", systemImage: "battery.25percent")
                    .frame(maxWidth: .infinity)
            }
            .tint(.blue)

            Button {
                selectedEnergy = 3
                WKInterfaceDevice.current().play(.click)
                step = .mood
            } label: {
                Label("Medium", systemImage: "battery.50percent")
                    .frame(maxWidth: .infinity)
            }
            .tint(.orange)

            Button {
                selectedEnergy = 5
                WKInterfaceDevice.current().play(.click)
                step = .mood
            } label: {
                Label("High", systemImage: "battery.100percent")
                    .frame(maxWidth: .infinity)
            }
            .tint(.green)
        }
    }

    // MARK: - Mood Selection

    private var moodSelectionView: some View {
        VStack(spacing: 12) {
            Text("How's your mood?")
                .font(.headline)

            Button {
                submitMood(moodLevel: 1)
            } label: {
                Label("Down", systemImage: "cloud.rain")
                    .frame(maxWidth: .infinity)
            }
            .tint(.blue)

            Button {
                submitMood(moodLevel: 3)
            } label: {
                Label("Neutral", systemImage: "cloud.sun")
                    .frame(maxWidth: .infinity)
            }
            .tint(.orange)

            Button {
                submitMood(moodLevel: 5)
            } label: {
                Label("Great", systemImage: "sun.max.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.green)
        }
    }

    // MARK: - Confirmation View

    private var confirmationView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Mood Set")
                .font(.headline)
            Text("Energy: \(energyLabel) / Mood: \(moodLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var energyLabel: String {
        switch selectedEnergy {
        case 1: return "Low"
        case 3: return "Medium"
        case 5: return "High"
        default: return "?"
        }
    }

    private var moodLabel: String {
        switch selectedMood {
        case 1: return "Down"
        case 3: return "Neutral"
        case 5: return "Great"
        default: return "?"
        }
    }

    // MARK: - Submit

    private func submitMood(moodLevel: Int) {
        guard !hasSubmitted else { return }
        hasSubmitted = true
        selectedMood = moodLevel

        let packet = MoodPacket(
            moodLevel: moodLevel,
            energyLevel: selectedEnergy,
            timestamp: Date()
        )
        connectivityService.sendMoodInput(packet)
        WKInterfaceDevice.current().play(.success)

        withAnimation {
            step = .confirmed
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

#Preview {
    WatchMoodInputView(connectivityService: PhoneConnectivityService())
}
