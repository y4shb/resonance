//
//  StateDebugView.swift
//  Resonance
//
//  Debug view showing the current StateVector, data sources,
//  confidence level, and inferred context/need. Accessible from Settings.
//

import SwiftUI

struct StateDebugView: View {
    @ObservedObject var stateEngine: StateEngine

    var body: some View {
        List {
            stateSection
            dimensionsSection
            dataSourcesSection
            rawBiometricSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("State Debug")
    }

    // MARK: - State Overview

    private var stateSection: some View {
        Section {
            LabeledRow(label: "Context", value: state.context.displayName)
            LabeledRow(label: "Music Need", value: state.inferredNeed.displayName)
            LabeledRow(label: "Confidence", value: "\(Int(state.confidence * 100))%")
            LabeledRow(label: "Dominant", value: state.dominantCharacteristic)
            LabeledRow(label: "Updated", value: state.timestamp.formatted(date: .omitted, time: .standard))
        } header: {
            Text("Current State")
        }
    }

    // MARK: - Dimensions

    private var dimensionsSection: some View {
        Section {
            DimensionBar(label: "Arousal", value: state.arousal, color: .red)
            DimensionBar(label: "Energy", value: state.energy, color: .orange)
            DimensionBar(label: "Focus", value: state.focus, color: .blue)
            DimensionBar(label: "Stress", value: state.stress, color: .purple)
            DimensionBar(label: "Valence", value: state.valence, color: .green)
        } header: {
            Text("Dimensions (0.0 - 1.0)")
        }
    }

    // MARK: - Data Sources

    private var dataSourcesSection: some View {
        Section {
            if state.dataSources.isEmpty {
                Text("No active data sources")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(state.dataSources).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { source in
                    Label(source.displayName, systemImage: iconForSource(source))
                }
            }
        } header: {
            Text("Active Data Sources")
        }
    }

    // MARK: - Raw Biometric

    private var rawBiometricSection: some View {
        Section {
            if let prev = stateEngine.previousState {
                LabeledRow(
                    label: "Arousal Delta",
                    value: String(format: "%+.3f", state.arousal - prev.arousal)
                )
                LabeledRow(
                    label: "Stress Delta",
                    value: String(format: "%+.3f", state.stress - prev.stress)
                )
                LabeledRow(
                    label: "Energy Delta",
                    value: String(format: "%+.3f", state.energy - prev.energy)
                )
            } else {
                Text("No previous state for comparison")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("State Deltas")
        }
    }

    // MARK: - Helpers

    private var state: StateVector {
        stateEngine.currentState
    }

    private func iconForSource(_ source: DataSource) -> String {
        switch source {
        case .heartRate: return "heart.fill"
        case .hrv: return "waveform.path.ecg"
        case .motion: return "figure.walk"
        case .macOSContext: return "desktopcomputer"
        case .calendarContext: return "calendar"
        case .timeOfDay: return "clock"
        case .manualMoodInput: return "hand.tap"
        case .historicalPattern: return "chart.line.uptrend.xyaxis"
        case .crownInput: return "digitalcrown.horizontal.arrow.counterclockwise"
        }
    }
}

// MARK: - Supporting Views

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}

private struct DimensionBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(1, max(0, value)), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        StateDebugView(
            stateEngine: StateEngine(
                contextCollector: ContextCollector(),
                healthKitService: HealthKitService()
            )
        )
    }
}
