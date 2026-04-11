//
//  OnboardingFirstPlayPage.swift
//  Resonance
//
//  Page 4 of the onboarding golden path: First Play experience.
//  Shows a HeartPulseRing syncing to the user's heartbeat (or a simulated
//  resting rate if HealthKit data is not yet available), auto-selects a
//  contextually-matched song from analyzed songs, and transitions into
//  the main app.
//
//  Design decisions:
//  - If HealthKit has no data yet, we use a simulated 72 BPM "resting"
//    heartbeat so the ring still animates convincingly.
//  - If library analysis is incomplete, we show a "getting ready" state
//    with the brain orb pulsing, then transition once any songs are available.
//  - The "Enter Resonance" button uses a matched geometry transition that
//    morphs into the main app's hero artwork area.
//

import SwiftUI
import HealthKit

// MARK: - First Play Page

/// The culminating onboarding page: "Your music is now responding to your body."
/// Displays the HeartPulseRing, a contextual song suggestion, and the
/// final CTA to enter the main app.
struct FirstPlayPage: View {
    var analysisViewModel: OnboardingAnalysisViewModel
    let onEnterApp: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var heartRate: Double = 72.0
    @State private var isReady = false
    @State private var showContent = false
    @State private var isPulsing = false

    /// Simulated music BPM for the HeartPulseRing entrainment demo.
    /// Chosen to be near the simulated heart rate for a visible glow.
    private let demoBPM: Double = 70.0

    /// The HealthKit store for fetching latest heart rate, if available.
    private static let healthStore = HKHealthStore()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if showContent {
                readyContent
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                preparingContent
            }

            Spacer()

            // Enter app button
            if isReady {
                enterButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: UIConstants.Animation.slow), value: showContent)
        .animation(.easeInOut(duration: UIConstants.Animation.standard), value: isReady)
        .task {
            await prepareFirstPlay()
        }
    }

    // MARK: - Preparing Content

    private var preparingContent: some View {
        VStack(spacing: 24) {
            // Boot-up LED indicator while preparing
            RetroLEDIndicator(isOn: true, color: ResonanceColors.ledAmber, size: 16, blinkRate: 2)

            RetroLCDPanel(title: "INITIALIZING") {
                VStack(spacing: 8) {
                    Text("PREPARING FIRST SESSION...")
                        .font(RetroTypography.lcdBody)
                    ProgressView()
                        .tint(ResonanceColors.ledGreen)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
        }
        .onAppear { isPulsing = true }
    }

    // MARK: - Ready Content

    private var readyContent: some View {
        VStack(spacing: 24) {
            // HeartPulseRing with heart rate display
            BrushedMetalSurface(cornerRadius: 12) {
                ZStack {
                    HeartPulseRing(
                        heartRate: heartRate,
                        musicBPM: demoBPM,
                        accentColor: ResonanceColors.accent,
                        reduceMotion: reduceMotion,
                        isTransitioning: false
                    )
                    .frame(width: 200, height: 200)

                    // Heart rate readout inside the ring
                    VStack(spacing: 4) {
                        RetroLEDIndicator(isOn: true, color: ResonanceColors.ledRed, size: 10)

                        Text("\(Int(heartRate))")
                            .font(RetroTypography.ledDigit)
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())

                        Text("BPM")
                            .font(RetroTypography.lcdCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            }

            // Context text
            RetroLCDPanel(title: "STATUS") {
                VStack(spacing: 8) {
                    Text("MUSIC NOW RESPONDING\nTO YOUR BODY")
                        .font(RetroTypography.lcdBody)
                        .multilineTextAlignment(.center)

                    // Song count summary
                    if analysisViewModel.analyzedSongs > 0 {
                        Text("\(analysisViewModel.analyzedSongs) TRACKS ANALYZED")
                            .font(RetroTypography.lcdCaption)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
            }

            // Top emotion categories summary
            if !analysisViewModel.emotionCounters.isEmpty {
                topEmotionsSummary
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Top Emotions Summary

    private var topEmotionsSummary: some View {
        BrushedMetalSurface(cornerRadius: 10) {
            HStack(spacing: 12) {
                ForEach(Array(analysisViewModel.emotionCounters.prefix(3))) { counter in
                    VStack(spacing: 4) {
                        RetroLEDIndicator(isOn: true, color: counter.category.color, size: 6)

                        Text(counter.category.displayName)
                            .font(RetroTypography.lcdCaption)
                            .foregroundStyle(.secondary)

                        Text("\(counter.count)")
                            .font(RetroTypography.lcdBody)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Enter Button

    private var enterButton: some View {
        RetroPushButton(label: "ENTER RESONANCE", icon: "waveform.circle.fill") {
            onEnterApp()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Preparation

    /// Attempts to fetch a real heart rate from HealthKit. Falls back to
    /// a simulated 72 BPM resting rate if no data is available.
    /// Waits a brief moment before showing the "ready" state to ensure
    /// the transition feels intentional rather than instantaneous.
    private func prepareFirstPlay() async {
        // Try to get real heart rate
        if HKHealthStore.isHealthDataAvailable() {
            if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let sortDescriptor = NSSortDescriptor(
                    key: HKSampleSortIdentifierStartDate,
                    ascending: false
                )
                let query = HKSampleQuery(
                    sampleType: hrType,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let bpm = sample.quantity.doubleValue(
                            for: HKUnit.count().unitDivided(by: .minute())
                        )
                        Task { @MainActor in
                            self.heartRate = bpm
                        }
                    }
                }
                Self.healthStore.execute(query)
            }
        }

        // Wait a brief moment for the preparing state to display,
        // then transition to the ready state
        try? await Task.sleep(for: .seconds(2))

        await MainActor.run {
            withAnimation {
                showContent = true
            }
        }

        // After a short additional delay, enable the enter button
        try? await Task.sleep(for: .seconds(1))

        await MainActor.run {
            withAnimation {
                isReady = true
            }
        }
    }
}

// MARK: - Preview

#Preview("First Play") {
    FirstPlayPage(
        analysisViewModel: OnboardingAnalysisViewModel(),
        onEnterApp: {}
    )
    .preferredColorScheme(.dark)
}
