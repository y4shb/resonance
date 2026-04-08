//
//  OnboardingMusicConnectionPage.swift
//  Resonance
//
//  Page 2 of the onboarding golden path: Apple Music connection with
//  inline library analysis and real-time emotion category counters.
//
//  On MusicKit grant, immediately starts background library analysis and
//  shows emotion tags animating in real-time. A "Continue" button appears
//  after 10 seconds or 20% progress (whichever comes first), so the user
//  is never blocked waiting for analysis to finish.
//

import SwiftUI
import MusicKit

// MARK: - Page 2: Music Connection

/// MusicKit permission + inline library analysis with real-time emotion counters.
/// On grant: immediately starts analysis, shows emotion tags animating in.
/// "Continue" button appears after 10 seconds or 20% progress.
struct MusicConnectionPage: View {
    @ObservedObject var musicService: MusicKitService
    var analysisViewModel: OnboardingAnalysisViewModel
    @Binding var isAuthorized: Bool
    @Binding var isDenied: Bool
    let onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Icon
                Image(systemName: "music.note.list")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 20)

                // Pre-permission copy
                if !isAuthorized && !analysisViewModel.analysisStarted {
                    prePermissionSection
                } else if isAuthorized || analysisViewModel.analysisStarted {
                    analysisSection
                } else if isDenied {
                    deniedSection
                }

                Spacer(minLength: 20)

                // Continue button (appears after analysis progress threshold)
                if analysisViewModel.canContinue || isDenied {
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.headline)
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
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Skip for non-denied, non-authorized state
                if !isAuthorized && !analysisViewModel.analysisStarted && !isDenied {
                    skipButton
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: UIConstants.Animation.standard), value: isAuthorized)
            .animation(.easeInOut(duration: UIConstants.Animation.standard), value: analysisViewModel.canContinue)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Pre-Permission

    private var prePermissionSection: some View {
        VStack(spacing: 20) {
            Text("Let me browse your music\nso I can learn your taste")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Button {
                requestMusicAccess()
            } label: {
                HStack(spacing: 8) {
                    if isRequesting {
                        ProgressView().tint(.white)
                    }
                    Text("Connect Apple Music")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.pink)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isRequesting)
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Denied State

    private var deniedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)

            Text("Apple Music access is needed\nto analyze your library")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("You can grant access later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.subheadline)
                    .foregroundStyle(ResonanceColors.accent)
            }
        }
    }

    // MARK: - Analysis Section (inline library analysis)

    private var analysisSection: some View {
        VStack(spacing: 16) {
            // Connected badge
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Apple Music Connected")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            .padding(.bottom, 8)

            // Phase description
            Text(analysisPhaseText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Progress bar
            if analysisViewModel.totalSongs > 0 {
                VStack(spacing: 6) {
                    ProgressView(value: analysisViewModel.progress)
                        .progressViewStyle(.linear)
                        .tint(ResonanceColors.accent)

                    Text("\(analysisViewModel.analyzedSongs) of \(analysisViewModel.totalSongs) songs")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 16)
            }

            // Emotion tag counters
            if !analysisViewModel.emotionCounters.isEmpty {
                emotionTagGrid
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Emotion Tag Grid

    private var emotionTagGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Discovering your music's emotions...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            // Show top 6 categories in a flowing grid
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(Array(analysisViewModel.emotionCounters.prefix(6))) { counter in
                    EmotionTagRow(
                        counter: counter,
                        isHighlighted: counter.category == analysisViewModel.lastUpdatedCategory
                    )
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button {
            logInfo("User skipped MusicKit during onboarding", category: .ui)
            onContinue()
        } label: {
            Text("I'll set this up later")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private var analysisPhaseText: String {
        if analysisViewModel.analysisComplete {
            return "Your library is analyzed and ready"
        } else if analysisViewModel.totalSongs > 0 {
            return "Learning your music taste..."
        } else {
            return "Scanning your library..."
        }
    }

    private func requestMusicAccess() {
        isRequesting = true
        logInfo("Onboarding: user tapped Connect Apple Music", category: .ui)

        Task {
            let status = await musicService.requestAuthorization()

            await MainActor.run {
                isRequesting = false
                isAuthorized = status == .authorized
                isDenied = status == .denied || status == .restricted

                if status == .authorized {
                    logInfo("MusicKit authorized during onboarding -- starting analysis", category: .ui)
                    // Immediately start background analysis
                    analysisViewModel.startAnalysis(musicService: musicService)
                }
            }
        }
    }
}

// MARK: - Emotion Tag Row

/// A single emotion category counter row with an animated count.
struct EmotionTagRow: View {
    let counter: EmotionTagCounter
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(counter.category.color)
                .frame(width: 10, height: 10)

            Text(counter.category.displayName)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text("\(counter.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(counter.category.color.opacity(isHighlighted ? 0.15 : 0.06))
        )
        .animation(.easeOut(duration: 0.3), value: isHighlighted)
    }
}

// MARK: - Preview

#Preview("Music Connection - Pre-Permission") {
    MusicConnectionPage(
        musicService: MusicKitService(),
        analysisViewModel: OnboardingAnalysisViewModel(),
        isAuthorized: .constant(false),
        isDenied: .constant(false),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Music Connection - Denied") {
    MusicConnectionPage(
        musicService: MusicKitService(),
        analysisViewModel: OnboardingAnalysisViewModel(),
        isAuthorized: .constant(false),
        isDenied: .constant(true),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}
