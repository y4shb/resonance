//
//  OnboardingPageViews.swift
//  Resonance
//
//  Page views for the redesigned onboarding golden path:
//    1. BrainOrbWelcomePage - Animated brain orb + "Get Started"
//    2. MusicConnectionPage - MusicKit permission + inline library analysis
//    3. HealthKitConnectionPage - HealthKit permission with benefit rows
//
//  Page 4 (FirstPlayPage) is in OnboardingFirstPlayPage.swift to keep
//  each file under 500 lines.
//

import SwiftUI
import MusicKit
import HealthKit

// MARK: - Page 1: Brain Orb Welcome

/// Full-screen animated brain orb with app title and a single "Get Started" CTA.
/// Target dwell time: ~10 seconds. No value proposition text -- show value through action.
struct BrainOrbWelcomePage: View {
    let onGetStarted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Brain orb (reused from LandingView design)
            ZStack {
                // Outer pulse ring
                Circle()
                    .fill(ResonanceColors.accent.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                    .animation(
                        reduceMotion ? .none :
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                // Inner glow
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)

                // Brain icon
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ResonanceColors.accent, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Resonance brain icon")
            .padding(.bottom, 32)

            // Title
            Text("Resonance")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            // Subtitle
            Text("Your AI-Powered DJ")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            // Single CTA
            Button(action: onGetStarted) {
                Text("Get Started")
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
            .padding(.bottom, 48)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
        }
        .onAppear {
            isPulsing = true
            withAnimation(reduceMotion ? .none : .easeIn(duration: 0.6)) {
                isVisible = true
            }
        }
    }
}

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

                // Skip for denied state
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
private struct EmotionTagRow: View {
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

// MARK: - Page 3: HealthKit Connection

/// HealthKit permission page shown after library analysis has started,
/// so the user has already seen value from the music analysis.
struct HealthKitConnectionPage: View {
    @Binding var healthKitRequested: Bool
    let onContinue: () -> Void

    @State private var isRequesting = false
    @State private var healthKitAvailable = HKHealthStore.isHealthDataAvailable()
    private static let healthStore = HKHealthStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Icon
                Image(systemName: "heart.text.square")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 20)

                Text("Now let me tune\ninto your body")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                // Benefit rows
                VStack(alignment: .leading, spacing: 14) {
                    BenefitRow(
                        icon: "heart.fill",
                        iconColor: .red,
                        title: "Heart Rate Matching",
                        description: "Music tempo adapts to your heartbeat"
                    )

                    BenefitRow(
                        icon: "figure.run",
                        iconColor: .orange,
                        title: "Activity Detection",
                        description: "Energy shifts for workouts and rest"
                    )

                    BenefitRow(
                        icon: "lock.shield.fill",
                        iconColor: .green,
                        title: "Private by Design",
                        description: "All biometric data stays on your device"
                    )
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 32)

                // Grant / State
                if healthKitRequested {
                    grantedBadge
                        .padding(.bottom, 16)

                    continueButton
                } else if healthKitAvailable {
                    grantButton
                        .padding(.bottom, 8)

                    skipButton
                } else {
                    unavailableLabel
                        .padding(.bottom, 16)

                    continueButton
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Subviews

    private var grantedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("HealthKit Connected")
                .font(.headline)
                .foregroundStyle(.green)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var grantButton: some View {
        Button {
            requestHealthKitAccess()
        } label: {
            HStack(spacing: 8) {
                if isRequesting {
                    ProgressView().tint(.white)
                }
                Text("Connect HealthKit")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isRequesting)
        .padding(.horizontal, 8)
    }

    private var continueButton: some View {
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
        .padding(.horizontal, 8)
    }

    private var skipButton: some View {
        Button {
            logInfo("User skipped HealthKit during onboarding", category: .ui)
            onContinue()
        } label: {
            Text("I'll set this up later")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var unavailableLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("HealthKit is not available on this device")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func requestHealthKitAccess() {
        isRequesting = true
        logInfo("Onboarding: user tapped Connect HealthKit", category: .ui)

        Task {
            do {
                let readTypes = healthKitReadTypes()
                try await Self.healthStore.requestAuthorization(toShare: [], read: readTypes)

                await MainActor.run {
                    isRequesting = false
                    healthKitRequested = true
                    logInfo("HealthKit authorization requested during onboarding", category: .ui)
                    // Auto-advance after granting
                    onContinue()
                }
            } catch {
                await MainActor.run {
                    isRequesting = false
                    logError("HealthKit authorization failed during onboarding", error: error, category: .ui)
                    // Advance anyway to avoid trapping the user
                    onContinue()
                }
            }
        }
    }

    private func healthKitReadTypes() -> Set<HKObjectType> {
        var types = Set<HKObjectType>()
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .activeEnergyBurned,
            .stepCount,
        ]
        for identifier in quantityIdentifiers {
            if let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(quantityType)
            }
        }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }
}

// MARK: - Benefit Row (redesigned with title + description)

private struct BenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Previews

#Preview("Brain Orb Welcome") {
    BrainOrbWelcomePage(onGetStarted: {})
        .preferredColorScheme(.dark)
}

#Preview("Music Connection") {
    MusicConnectionPage(
        musicService: MusicKitService(),
        analysisViewModel: OnboardingAnalysisViewModel(),
        isAuthorized: .constant(false),
        isDenied: .constant(false),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("HealthKit Connection") {
    HealthKitConnectionPage(
        healthKitRequested: .constant(false),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}
