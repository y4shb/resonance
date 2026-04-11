//
//  OnboardingPageViews.swift
//  Resonance
//
//  Page views for the redesigned onboarding golden path:
//    1. BrainOrbWelcomePage - Animated brain orb + "Get Started"
//    3. HealthKitConnectionPage - HealthKit permission with benefit rows
//
//  Other pages are in their own files:
//  - OnboardingMusicConnectionPage.swift (Page 2: MusicConnectionPage)
//  - OnboardingFirstPlayPage.swift (Page 4: FirstPlayPage)
//

import SwiftUI
import HealthKit

// MARK: - Page 1: Brain Orb Welcome

/// Full-screen animated brain orb with app title and a single "Get Started" CTA.
/// Target dwell time: ~10 seconds. No value proposition text -- show value through action.
struct BrainOrbWelcomePage: View {
    let onGetStarted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var bootText = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            BrushedMetalSurface(cornerRadius: 12) {
                VStack(spacing: 16) {
                    // Boot LED indicator
                    RetroLEDIndicator(isOn: isVisible, color: ResonanceColors.ledGreen, size: 12)
                        .padding(.top, 20)

                    // Title
                    Text("RESONANCE")
                        .font(RetroTypography.lcdTitle)
                        .foregroundStyle(.primary)

                    // Boot LCD panel
                    RetroLCDPanel(title: "SYSTEM INIT") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bootText)
                                .font(RetroTypography.lcdBody)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)

                    Text("Your AI-Powered DJ")
                        .font(RetroTypography.lcdCaption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Resonance boot screen")
            .padding(.bottom, 32)

            Spacer()

            // Single CTA
            RetroPushButton(label: "GET STARTED", icon: "power") {
                onGetStarted()
            }
            .padding(.bottom, 48)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            startBootText()
        }
    }

    private func startBootText() {
        let lines = [
            "AI DJ ENGINE v2.0",
            "NEURAL CORE: ONLINE",
            "READY TO CONFIGURE"
        ]

        if reduceMotion {
            isVisible = true
            bootText = lines.joined(separator: "\n")
            return
        }

        withAnimation(.easeIn(duration: 0.3)) {
            isVisible = true
        }

        var delay: Double = 0.4
        for line in lines {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeIn(duration: 0.1)) {
                    if bootText.isEmpty {
                        bootText = line
                    } else {
                        bootText += "\n" + line
                    }
                }
            }
            delay += 0.3
        }
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

                Text("BIOMETRIC LINK")
                    .retroEngravedLabel()
                    .padding(.bottom, 4)

                Text("Now let me tune\ninto your body")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                // Benefit rows
                VStack(alignment: .leading, spacing: 14) {
                    OnboardingBenefitRow(
                        icon: "heart.fill",
                        iconColor: .red,
                        title: "Heart Rate Matching",
                        description: "Music tempo adapts to your heartbeat"
                    )

                    OnboardingBenefitRow(
                        icon: "figure.run",
                        iconColor: .orange,
                        title: "Activity Detection",
                        description: "Energy shifts for workouts and rest"
                    )

                    OnboardingBenefitRow(
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
            RetroLEDIndicator(isOn: true, color: .green, size: 10)
            Text("CONNECTED")
                .font(RetroTypography.lcdBody)
                .foregroundStyle(.green)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var grantButton: some View {
        RetroPushButton(label: "CONNECT", icon: "heart.fill") {
            requestHealthKitAccess()
        }
        .disabled(isRequesting)
        .padding(.horizontal, 8)
    }

    private var continueButton: some View {
        RetroPushButton(label: "CONTINUE", icon: "arrow.right") {
            onContinue()
        }
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

// MARK: - Onboarding Benefit Row

/// A benefit row with icon, title, and description for permission pages.
struct OnboardingBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            BrushedMetalSurface(cornerRadius: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RetroTypography.lcdBody)
                    .fontWeight(.semibold)

                Text(description)
                    .font(RetroTypography.lcdCaption)
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

#Preview("HealthKit Connection") {
    HealthKitConnectionPage(
        healthKitRequested: .constant(false),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}
