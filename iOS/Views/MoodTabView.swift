//
//  MoodTabView.swift
//  Resonance
//
//  "How are you feeling?" tab for guided mood journeys.
//  Lets users set their current and target mood via energy/valence sliders,
//  choose from preset moods, and start a trajectory-based music journey.
//

import SwiftUI

// MARK: - Mood Tab View

struct MoodTabView: View {
    // MARK: - Properties
    @ObservedObject var stateEngine: StateEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.retroAccentColor) private var accentColor

    // MARK: - State
    @State private var currentEnergy = Defaults.initialCurrentEnergy
    @State private var currentValence = Defaults.initialCurrentValence
    @State private var targetEnergy = Defaults.initialTargetEnergy
    @State private var targetValence = Defaults.initialTargetValence
    @State private var hasInitialized = false
    @State private var selectedPreset: MoodPreset = .calm

    private enum MoodPreset: String, CaseIterable {
        case calm = "CALM"
        case focus = "FOCUS"
        case energy = "ENERGY"
        case upbeat = "UPBEAT"

        var energy: Double {
            switch self {
            case .calm: return 0.2
            case .focus: return 0.5
            case .energy: return 0.85
            case .upbeat: return 0.75
            }
        }

        var valence: Double {
            switch self {
            case .calm: return 0.7
            case .focus: return 0.6
            case .energy: return 0.75
            case .upbeat: return 0.9
            }
        }
    }

    // MARK: - Constants
    private enum Defaults {
        static let initialCurrentEnergy: Double = 0.5
        static let initialCurrentValence: Double = 0.5
        static let initialTargetEnergy: Double = 0.7
        static let initialTargetValence: Double = 0.7
    }
    private enum SuggestionThresholds {
        static let similarMoodDelta: Double = 0.1
        static let significantDelta: Double = 0.2
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                BrushedMetalSurface(showScrews: true) {
                    VStack(spacing: 20) {
                        moodOrbSection
                        currentMoodSection
                        targetMoodSection
                        presetButtonsSection
                        suggestionPreview
                        if let trajectory = stateEngine.moodTrajectory {
                            journeyProgressSection(trajectory: trajectory)
                        } else {
                            startJourneyButton
                        }
                    }
                    .padding(.vertical, 16)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(ResonanceColors.panelBg)
            .navigationTitle("Mood")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initializeFromState()
            }
        }
    }

    // MARK: - Mood VU Meters

    private var moodOrbSection: some View {
        HStack(spacing: 20) {
            RetroVUMeter(value: currentEnergy, label: "ENERGY", showPeakHold: true, size: 140)
            RetroVUMeter(value: currentValence, label: "VALENCE", showPeakHold: true, size: 140)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mood meters: Energy \(Int(currentEnergy * 100))%, Valence \(Int(currentValence * 100))%")
    }

    // MARK: - Current Mood Section

    private var currentMoodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT STATE")
                .retroEngravedLabel()

            RetroLCDPanel(title: "ENERGY / VALENCE") {
                HStack(spacing: 24) {
                    RetroKnob(value: $currentEnergy, detents: 10, label: "ENERGY", size: 56)
                    RetroKnob(value: $currentValence, detents: 10, label: "VALENCE", size: 56)
                }
                .padding(16)
            }

            // Current state readout
            HStack(spacing: 16) {
                RetroLCDPanel {
                    Text("E: \(String(format: "%.2f", currentEnergy))")
                        .font(RetroTypography.lcdBody)
                        .padding(8)
                }
                RetroLCDPanel {
                    Text("V: \(String(format: "%.2f", currentValence))")
                        .font(RetroTypography.lcdBody)
                        .padding(8)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Target Mood Section

    private var targetMoodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TARGET STATE")
                .retroEngravedLabel()

            RetroLCDPanel(title: "TARGET ENERGY / VALENCE") {
                HStack(spacing: 24) {
                    RetroKnob(value: $targetEnergy, detents: 10, label: "ENERGY", size: 56)
                    RetroKnob(value: $targetValence, detents: 10, label: "VALENCE", size: 56)
                }
                .padding(16)
            }

            // Delta readout
            RetroLCDPanel(title: "DELTA") {
                HStack(spacing: 16) {
                    Text("ΔE: \(formatDelta(targetEnergy - currentEnergy))")
                        .font(RetroTypography.lcdBody)
                    Text("ΔV: \(formatDelta(targetValence - currentValence))")
                        .font(RetroTypography.lcdBody)
                }
                .padding(8)
            }
        }
        .padding(16)
    }

    // MARK: - Preset Selector

    private var presetButtonsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRESETS")
                .retroEngravedLabel()

            RetroSegmentedSelector(
                selection: $selectedPreset,
                options: MoodPreset.allCases,
                label: { $0.rawValue }
            )
            .onChange(of: selectedPreset) { _, newPreset in
                withAnimation(.spring(RetroAnimation.knobRotation)) {
                    targetEnergy = newPreset.energy
                    targetValence = newPreset.valence
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Suggestion Preview

    private var suggestionPreview: some View {
        RetroLCDPanel(title: "AI RECOMMENDATION") {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestionText)
                    .font(RetroTypography.lcdBody)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Start Journey Button

    private var startJourneyButton: some View {
        HStack {
            Spacer()
            RetroPushButton(label: "START JOURNEY", icon: "play.fill") {
                startJourney()
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Journey Progress

    private func journeyProgressSection(trajectory: MoodTrajectory) -> some View {
        VStack(spacing: 16) {
            HStack {
                RetroLEDIndicator(isOn: true, color: ResonanceColors.ledGreen, blinkRate: 1)
                Text("JOURNEY ACTIVE")
                    .retroEngravedLabel()
                Spacer()
            }

            // Tape counter showing progress
            RetroLCDPanel(title: "PROGRESS") {
                VStack(spacing: 8) {
                    // 4-digit counter
                    Text(String(format: "%04d", Int(journeyProgress(trajectory: trajectory) * 9999)))
                        .font(RetroTypography.ledDigit)
                        .padding(.vertical, 8)

                    // LED bar graph
                    HStack(spacing: 2) {
                        ForEach(0..<10, id: \.self) { i in
                            let threshold = Double(i) / 10.0
                            let progress = journeyProgress(trajectory: trajectory)
                            RetroLEDIndicator(
                                isOn: progress > threshold,
                                color: i < 6 ? ResonanceColors.ledGreen : (i < 8 ? ResonanceColors.ledAmber : ResonanceColors.ledRed),
                                size: 6
                            )
                        }
                    }

                    // Journey info
                    HStack(spacing: 12) {
                        Text("FROM: \(energyLabel(for: trajectory.currentEnergy))")
                            .font(RetroTypography.lcdCaption)
                        Text("TO: \(energyLabel(for: trajectory.targetEnergy))")
                            .font(RetroTypography.lcdCaption)
                    }
                    .padding(.top, 4)
                }
                .padding(12)
            }

            RetroPushButton(label: "STOP", icon: "stop.fill") {
                stateEngine.clearMoodTrajectory()
            }
        }
        .padding(16)
    }

    // MARK: - Actions

    private func initializeFromState() {
        guard !hasInitialized else { return }
        hasInitialized = true

        if let mood = stateEngine.manualMood, mood.isActive {
            currentEnergy = mood.energy
            currentValence = mood.valence
        } else {
            currentEnergy = stateEngine.currentState.energy
            currentValence = stateEngine.currentState.valence
        }
    }

    private func startJourney() {
        stateEngine.setMoodTrajectory(
            current: (energy: currentEnergy, valence: currentValence),
            target: (energy: targetEnergy, valence: targetValence)
        )
    }

    // MARK: - Computed Helpers

    private var suggestionText: String {
        let eDelta = targetEnergy - currentEnergy
        let vDelta = targetValence - currentValence

        if abs(eDelta) < SuggestionThresholds.similarMoodDelta
            && abs(vDelta) < SuggestionThresholds.similarMoodDelta {
            return "Your current and target moods are similar. Music will maintain your state."
        }

        var parts: [String] = []
        if eDelta > SuggestionThresholds.significantDelta {
            parts.append("upbeat tracks to boost your energy")
        } else if eDelta < -SuggestionThresholds.significantDelta {
            parts.append("mellow tracks to bring your energy down")
        }
        if vDelta > SuggestionThresholds.significantDelta {
            parts.append("feel-good songs to lift your mood")
        } else if vDelta < -SuggestionThresholds.significantDelta {
            parts.append("introspective music for reflection")
        }

        if parts.isEmpty {
            return "A gentle shift in music will guide you toward your target mood."
        }
        return "Resonance will use \(parts.joined(separator: " and ")) to guide your journey."
    }

    private func journeyProgress(trajectory: MoodTrajectory) -> Double {
        let totalGap = trajectory.gapMagnitude
        guard totalGap > 0 else { return 1.0 }
        let s = stateEngine.currentState
        let dE = trajectory.targetEnergy - s.energy
        let dV = trajectory.targetValence - s.valence
        let remaining = (dE * dE + dV * dV).squareRoot()
        return min(max(1.0 - (remaining / totalGap), 0.0), 1.0)
    }

    private func formatDelta(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", delta))"
    }

    // MARK: - Labels

    private func energyLabel(for value: Double) -> String {
        switch value {
        case 0..<0.2: return "Exhausted"
        case 0.2..<0.4: return "Tired"
        case 0.4..<0.6: return "Moderate"
        case 0.6..<0.8: return "Energetic"
        default: return "Pumped"
        }
    }

    private func valenceLabel(for value: Double) -> String {
        switch value {
        case 0..<0.2: return "Low"
        case 0.2..<0.4: return "Down"
        case 0.4..<0.6: return "Neutral"
        case 0.6..<0.8: return "Good"
        default: return "Great"
        }
    }
}

// MARK: - Preview

#Preview {
    MoodTabView(
        stateEngine: StateEngine(
            contextCollector: ContextCollector(),
            healthKitService: HealthKitService()
        )
    )
}
