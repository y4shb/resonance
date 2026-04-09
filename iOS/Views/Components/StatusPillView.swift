//
//  StatusPillView.swift
//  Resonance
//
//  Compact glass pill displaying the user's current biometric/context state.
//  Replaces the three separate bars (HRV zone, state info, active playlist)
//  from the old Now Playing layout with a single tappable indicator.
//
//  Tapping expands a detail sheet with full state breakdown.
//

import SwiftUI

// MARK: - Status Pill View

struct StatusPillView: View {
    @ObservedObject var stateEngine: StateEngine
    var activePlaylistName: String?
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 6) {
                // HRV zone dot
                Circle()
                    .fill(hrvZoneColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: hrvZoneColor.opacity(0.5), radius: 3)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(stateEngine.currentState.inferredNeed.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(ResonanceColors.accent)

                Text("\(Int(stateEngine.currentState.confidence * 100))%")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()

                if let playlist = activePlaylistName {
                    Circle()
                        .fill(.tertiary)
                        .frame(width: 3, height: 3)

                    Text(playlist)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Tap to see detailed state information")
        .sheet(isPresented: $showDetail) {
            StatusDetailSheet(
                stateEngine: stateEngine,
                activePlaylistName: activePlaylistName
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Computed

    private var hrvZoneColor: Color {
        let stress = stateEngine.currentState.stress
        if stress < 0.35 { return .green }
        else if stress < 0.65 { return .yellow }
        else { return .red }
    }

    private var accessibilityDescription: String {
        var parts = [
            "State: \(stateEngine.currentState.context.displayName)",
            "Need: \(stateEngine.currentState.inferredNeed.displayName)",
            "Confidence: \(Int(stateEngine.currentState.confidence * 100)) percent"
        ]
        if let playlist = activePlaylistName {
            parts.append("Playing from: \(playlist)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Status Detail Sheet

struct StatusDetailSheet: View {
    @ObservedObject var stateEngine: StateEngine
    var activePlaylistName: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Current State") {
                    LabeledContent("Context") {
                        Text(stateEngine.currentState.context.displayName)
                    }
                    LabeledContent("Need") {
                        Text(stateEngine.currentState.inferredNeed.displayName)
                            .foregroundStyle(ResonanceColors.accent)
                    }
                    LabeledContent("Confidence") {
                        Text("\(Int(stateEngine.currentState.confidence * 100))%")
                    }
                }

                Section("Biometrics") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(hrvZoneColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: hrvZoneColor.opacity(0.5), radius: 3)
                        Text("HRV Zone")
                        Spacer()
                        Text(hrvZoneName)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Stress") {
                        Text(String(format: "%.0f%%", stateEngine.currentState.stress * 100))
                    }
                    LabeledContent("Energy") {
                        Text(String(format: "%.0f%%", stateEngine.currentState.energy * 100))
                    }
                    LabeledContent("Arousal") {
                        Text(String(format: "%.0f%%", stateEngine.currentState.arousal * 100))
                    }
                    LabeledContent("Valence") {
                        Text(String(format: "%.0f%%", stateEngine.currentState.valence * 100))
                    }
                }

                if let playlist = activePlaylistName {
                    Section("Playback") {
                        LabeledContent("Playing from") {
                            Text(playlist)
                        }
                    }
                }
            }
            .navigationTitle("Your State")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var hrvZoneColor: Color {
        let stress = stateEngine.currentState.stress
        if stress < 0.35 { return .green }
        else if stress < 0.65 { return .yellow }
        else { return .red }
    }

    private var hrvZoneName: String {
        let stress = stateEngine.currentState.stress
        if stress < 0.35 { return "Recovered" }
        else if stress < 0.65 { return "Normal" }
        else { return "Stressed" }
    }
}
