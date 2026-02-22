//
//  OnboardingPageViews.swift
//  Resonance
//
//  Individual page views for the onboarding flow: Welcome, Value Proposition,
//  MusicKit Permission, and HealthKit Permission. Split from OnboardingContainerView
//  for readability.
//

import SwiftUI
import MusicKit
import HealthKit

// MARK: - Welcome Page

struct WelcomePage: View {
    let pageHeight: CGFloat

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .blue.opacity(0.3), radius: 20, y: 10)

            // App name
            Text("Resonance")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Tagline
            Text("Music that adapts to you")
                .font(.title2)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(height: pageHeight)
        .padding(.horizontal, 32)
    }
}

// MARK: - Value Proposition Page

struct ValuePropositionPage: View {
    let pageHeight: CGFloat

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                Text("How It Works")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 24)

                VStack(spacing: 20) {
                    FeatureCard(
                        icon: "heart.fill",
                        iconColor: .red,
                        title: "Biometric Sensing",
                        description: "Reads your heart rate and activity to understand how you feel right now."
                    )

                    FeatureCard(
                        icon: "brain.head.profile",
                        iconColor: .purple,
                        title: "AI DJ",
                        description: "Picks the perfect song for your current state and context."
                    )

                    FeatureCard(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .blue,
                        title: "Learns Over Time",
                        description: "Gets smarter with every listen, adapting to your unique preferences."
                    )
                }

                Spacer(minLength: 20)
            }
            .frame(minHeight: pageHeight)
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - MusicKit Permission Page

struct MusicKitPermissionPage: View {
    @ObservedObject var musicService: MusicKitService
    @Binding var isAuthorized: Bool
    let pageHeight: CGFloat

    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Icon
                Image(systemName: "music.note.list")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 24)

                Text("Access Your Music Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                // Benefits list
                VStack(alignment: .leading, spacing: 12) {
                    BenefitRow(icon: "play.circle", text: "Play songs from your library")
                    BenefitRow(icon: "list.bullet", text: "Read your playlists")
                    BenefitRow(icon: "lock.shield", text: "All data stays on your device")
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 32)

                Spacer(minLength: 20)

                // Authorization state
                if isAuthorized {
                    authorizedBadge
                } else {
                    grantAccessButton
                    maybeLaterButton
                        .padding(.top, 8)
                }

                Spacer(minLength: 20)
            }
            .frame(minHeight: pageHeight)
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            isAuthorized = musicService.authorizationStatus == .authorized
        }
    }

    // MARK: - Subviews

    private var authorizedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
            Text("Apple Music Connected")
                .font(.headline)
                .foregroundStyle(.green)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var grantAccessButton: some View {
        Button {
            requestMusicKitAccess()
        } label: {
            HStack {
                if isRequesting {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 4)
                }
                Text("Grant Access")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.pink)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isRequesting)
    }

    private var maybeLaterButton: some View {
        Button {
            logInfo("User skipped MusicKit authorization during onboarding", category: .ui)
        } label: {
            Text("Maybe Later")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func requestMusicKitAccess() {
        isRequesting = true
        logInfo("User tapped Grant Access for MusicKit", category: .ui)

        Task {
            let status = await musicService.requestAuthorization()

            await MainActor.run {
                isRequesting = false
                isAuthorized = status == .authorized

                if status == .authorized {
                    logInfo("MusicKit authorized during onboarding", category: .ui)
                } else {
                    logWarning("MusicKit authorization not granted during onboarding: \(status)", category: .ui)
                }
            }
        }
    }
}

// MARK: - HealthKit Permission Page

struct HealthKitPermissionPage: View {
    @Binding var healthKitRequested: Bool
    let pageHeight: CGFloat

    @State private var isRequesting = false
    @State private var healthKitAvailable = HKHealthStore.isHealthDataAvailable()

    private let healthStore = HKHealthStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Icon
                Image(systemName: "heart.text.square")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 24)

                Text("Health & Activity Data")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                // Benefits list
                VStack(alignment: .leading, spacing: 12) {
                    BenefitRow(icon: "heart.fill", text: "Heart rate for intensity matching")
                    BenefitRow(icon: "figure.run", text: "Activity detection for workouts")
                    BenefitRow(icon: "lock.shield", text: "Everything stays on-device")
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 32)

                Spacer(minLength: 20)

                // Authorization state
                if healthKitRequested {
                    healthKitGrantedBadge
                } else if healthKitAvailable {
                    grantHealthAccessButton
                    maybeLaterButton
                        .padding(.top, 8)
                } else {
                    healthKitUnavailableLabel
                }

                Spacer(minLength: 20)
            }
            .frame(minHeight: pageHeight)
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Subviews

    private var healthKitGrantedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
            Text("HealthKit Access Requested")
                .font(.headline)
                .foregroundStyle(.green)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var grantHealthAccessButton: some View {
        Button {
            requestHealthKitAccess()
        } label: {
            HStack {
                if isRequesting {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 4)
                }
                Text("Grant Access")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isRequesting)
    }

    private var maybeLaterButton: some View {
        Button {
            logInfo("User skipped HealthKit authorization during onboarding", category: .ui)
        } label: {
            Text("Maybe Later")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var healthKitUnavailableLabel: some View {
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
        logInfo("User tapped Grant Access for HealthKit", category: .ui)

        Task {
            do {
                let readTypes = healthKitReadTypes()
                try await healthStore.requestAuthorization(toShare: [], read: readTypes)

                await MainActor.run {
                    isRequesting = false
                    healthKitRequested = true
                    logInfo("HealthKit authorization requested during onboarding", category: .ui)
                }
            } catch {
                await MainActor.run {
                    isRequesting = false
                    logError("HealthKit authorization request failed during onboarding", error: error, category: .ui)
                }
            }
        }
    }

    /// Builds the set of HealthKit types to request read access for.
    private func healthKitReadTypes() -> Set<HKObjectType> {
        var types = Set<HKObjectType>()

        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
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

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Previews

#Preview("Welcome") {
    WelcomePage(pageHeight: 700)
}

#Preview("Value Proposition") {
    ValuePropositionPage(pageHeight: 700)
}

#Preview("MusicKit Permission") {
    MusicKitPermissionPage(
        musicService: MusicKitService(),
        isAuthorized: .constant(false),
        pageHeight: 700
    )
}

#Preview("HealthKit Permission") {
    HealthKitPermissionPage(
        healthKitRequested: .constant(false),
        pageHeight: 700
    )
}
