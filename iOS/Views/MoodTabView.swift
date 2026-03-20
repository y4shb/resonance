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

    // MARK: - State
    @State private var currentEnergy = Defaults.initialCurrentEnergy
    @State private var currentValence = Defaults.initialCurrentValence
    @State private var targetEnergy = Defaults.initialTargetEnergy
    @State private var targetValence = Defaults.initialTargetValence
    @State private var hasStartedJourney = false
    @State private var hasInitialized = false

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
                VStack(spacing: 28) {
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
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Mood")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                initializeFromState()
            }
        }
    }

    // MARK: - Mood Orb

    private var moodOrbSection: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: orbGradientColors),
                        center: .center,
                        startRadius: 5,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .blur(radius: 20)
                .opacity(0.6)

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: orbGradientColors),
                        center: .center,
                        startRadius: 2,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)

            VStack(spacing: 2) {
                Image(systemName: moodSystemImage)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                Text(moodSummaryLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mood indicator: \(moodSummaryLabel)")
    }

    // MARK: - Current Mood Section

    private var currentMoodSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How are you feeling right now?")
                .font(.headline)

            sliderRow(
                label: "Energy",
                value: $currentEnergy,
                lowLabel: "Low",
                highLabel: "High",
                tint: .orange,
                displayText: energyLabel(for: currentEnergy)
            )

            sliderRow(
                label: "Mood",
                value: $currentValence,
                lowLabel: "Down",
                highLabel: "Great",
                tint: .blue,
                displayText: valenceLabel(for: currentValence)
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Target Mood Section

    private var targetMoodSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How would you like to feel?")
                .font(.headline)

            sliderRow(
                label: "Target Energy",
                value: $targetEnergy,
                lowLabel: "Low",
                highLabel: "High",
                tint: .orange,
                displayText: energyLabel(for: targetEnergy)
            )

            sliderRow(
                label: "Target Mood",
                value: $targetValence,
                lowLabel: "Down",
                highLabel: "Great",
                tint: .blue,
                displayText: valenceLabel(for: targetValence)
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Preset Buttons

    private var presetButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Presets")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                presetButton(
                    title: "Energized",
                    icon: "bolt.fill",
                    energy: 0.85,
                    valence: 0.75,
                    color: .orange
                )
                presetButton(
                    title: "Calm & Relaxed",
                    icon: "leaf.fill",
                    energy: 0.2,
                    valence: 0.7,
                    color: .green
                )
                presetButton(
                    title: "Focused",
                    icon: "eye.fill",
                    energy: 0.5,
                    valence: 0.6,
                    color: .purple
                )
                presetButton(
                    title: "Happy & Upbeat",
                    icon: "sun.max.fill",
                    energy: 0.75,
                    valence: 0.9,
                    color: .yellow
                )
            }
        }
    }

    // MARK: - Suggestion Preview

    private var suggestionPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Music Suggestion")
                .font(.headline)

            Text(suggestionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Start Journey Button

    private var startJourneyButton: some View {
        Button {
            startJourney()
        } label: {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                Text("Start Journey")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("Start mood journey")
        .accessibilityHint(
            "Begin a music journey from your current mood to your target mood"
        )
    }

    // MARK: - Journey Progress

    private func journeyProgressSection(trajectory: MoodTrajectory) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "music.note.tv.fill")
                    .foregroundStyle(.green)
                Text("Journey Active")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                journeyInfoRow("From:", value: "\(energyLabel(for: trajectory.currentEnergy)), \(valenceLabel(for: trajectory.currentValence))")
                journeyInfoRow("To:", value: "\(energyLabel(for: trajectory.targetEnergy)), \(valenceLabel(for: trajectory.targetValence))")
                journeyInfoRow("Estimated songs:", value: "~\(trajectory.estimatedSongsToTarget)", bold: true)
            }

            // Progress bar visualization
            ProgressView(value: journeyProgress(trajectory: trajectory))
                .tint(.green)
                .accessibilityLabel(
                    "Journey progress: \(Int(journeyProgress(trajectory: trajectory) * 100))%"
                )

            Button(role: .destructive) {
                stateEngine.clearMoodTrajectory()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("End Journey")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemGray5))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("End mood journey")
            .accessibilityHint("Stops the current mood journey and clears the trajectory")
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Journey Info Row

    private func journeyInfoRow(_ label: String, value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(bold ? .medium : .regular)
        }
    }

    // MARK: - Shared Slider Row

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        lowLabel: String,
        highLabel: String,
        tint: Color,
        displayText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: 0...1, step: 0.05) {
                Text(label)
            } minimumValueLabel: {
                Text(lowLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(highLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .tint(tint)
            .accessibilityLabel(label)
            .accessibilityValue(displayText)
        }
    }

    // MARK: - Preset Button

    private func presetButton(
        title: String,
        icon: String,
        energy: Double,
        valence: Double,
        color: Color
    ) -> some View {
        Button {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                targetEnergy = energy
                targetValence = valence
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel("Set target to \(title)")
        .accessibilityHint("Sets target energy to \(energyLabel(for: energy)) and mood to \(valenceLabel(for: valence))")
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
        hasStartedJourney = true
    }

    // MARK: - Computed Helpers

    private var orbGradientColors: [Color] {
        let energyHue = currentEnergy * 0.12  // 0=red-ish, 1=orange-yellow
        let valenceShift = currentValence * 0.55 // shifts toward blue/purple
        let hue = energyHue + valenceShift
        let saturation = 0.5 + currentEnergy * 0.4
        let brightness = 0.5 + currentValence * 0.4
        return [
            Color(hue: hue, saturation: saturation, brightness: brightness),
            Color(hue: hue + 0.1, saturation: saturation * 0.8, brightness: brightness * 0.7)
        ]
    }

    private var moodSystemImage: String {
        switch (currentEnergy > 0.5, currentValence > 0.5) {
        case (true, true): return "bolt.heart.fill"
        case (true, false): return "exclamationmark.triangle.fill"
        case (false, true): return "leaf.fill"
        case (false, false): return "moon.zzz.fill"
        }
    }

    private var moodSummaryLabel: String {
        switch (currentEnergy > 0.5, currentValence > 0.5) {
        case (true, true): return "Energized"
        case (true, false): return "Tense"
        case (false, true): return "Calm"
        case (false, false): return "Tired"
        }
    }

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
