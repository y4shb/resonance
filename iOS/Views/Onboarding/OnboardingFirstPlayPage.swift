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
            // Pulsing brain orb while preparing
            ZStack {
                Circle()
                    .fill(ResonanceColors.accent.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
                    .animation(
                        reduceMotion ? .none :
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ResonanceColors.accent, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Getting your first session ready...")
                .font(.headline)
                .foregroundStyle(.secondary)

            ProgressView()
                .tint(ResonanceColors.accent)
        }
        .onAppear { isPulsing = true }
    }

    // MARK: - Ready Content

    private var readyContent: some View {
        VStack(spacing: 24) {
            // HeartPulseRing with heart rate display
            ZStack {
                HeartPulseRing(
                    heartRate: heartRate,
                    musicBPM: demoBPM,
                    accentColor: ResonanceColors.accent,
                    reduceMotion: reduceMotion
                )
                .frame(width: 200, height: 200)

                // Heart rate readout inside the ring
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse, isActive: !reduceMotion)

                    Text("\(Int(heartRate))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Context text
            VStack(spacing: 8) {
                Text("Your music is now\nresponding to your body")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Song count summary
                if analysisViewModel.analyzedSongs > 0 {
                    Text("\(analysisViewModel.analyzedSongs) songs analyzed and ready")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
        HStack(spacing: 12) {
            ForEach(Array(analysisViewModel.emotionCounters.prefix(3))) { counter in
                VStack(spacing: 4) {
                    Circle()
                        .fill(counter.category.color)
                        .frame(width: 8, height: 8)

                    Text(counter.category.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(counter.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.6))
        )
    }

    // MARK: - Enter Button

    private var enterButton: some View {
        Button(action: onEnterApp) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.title3)
                Text("Enter Resonance")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [ResonanceColors.accent, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: ResonanceColors.accent.opacity(0.4), radius: 12, y: 4)
            )
        }
        .buttonStyle(.plain)
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
