//
//  OnboardingContainerView.swift
//  Resonance
//
//  Swipeable onboarding flow with 4 pages: Welcome, Value Proposition,
//  MusicKit Permission, and HealthKit Permission. Guides the user through
//  initial setup and data access grants before entering the main app.
//

import SwiftUI
import MusicKit
import HealthKit

// MARK: - Onboarding Container View

struct OnboardingContainerView: View {
    // MARK: - Properties

    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var musicService: MusicKitService

    @State private var currentPage = 0
    @State private var musicKitAuthorized = false
    @State private var healthKitRequested = false

    private let totalPages = 4

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Page content
                    TabView(selection: $currentPage) {
                        WelcomePage(pageHeight: geo.size.height - bottomControlsHeight)
                            .tag(0)

                        ValuePropositionPage(pageHeight: geo.size.height - bottomControlsHeight)
                            .tag(1)

                        MusicKitPermissionPage(
                            musicService: musicService,
                            isAuthorized: $musicKitAuthorized,
                            pageHeight: geo.size.height - bottomControlsHeight
                        )
                        .tag(2)

                        HealthKitPermissionPage(
                            healthKitRequested: $healthKitRequested,
                            pageHeight: geo.size.height - bottomControlsHeight
                        )
                        .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: UIConstants.Animation.standard), value: currentPage)

                    // Bottom controls
                    bottomControls
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            logInfo("Onboarding flow started", category: .ui)
            // Sync initial MusicKit authorization state
            musicKitAuthorized = musicService.authorizationStatus == .authorized
        }
        .onChange(of: musicService.authorizationStatus) { _, newStatus in
            musicKitAuthorized = newStatus == .authorized
        }
    }

    // MARK: - Constants

    /// Approximate height of bottom controls (dots + button + padding)
    private var bottomControlsHeight: CGFloat { 100 }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? ResonanceColors.accent : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentPage ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: UIConstants.Animation.quick), value: currentPage)
                }
            }
            .padding(.top, 8)

            // Action button
            Button(action: handlePrimaryAction) {
                Text(primaryButtonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [ResonanceColors.accent, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Skip option for permission pages (reduces friction)
            if showSkipOption {
                Button(action: handleSkip) {
                    Text("I'll set this up later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var primaryButtonTitle: String {
        switch currentPage {
        case 2:
            return musicKitAuthorized ? "Continue" : "Grant Music Access"
        case 3:
            return "Get Started"
        default:
            return "Continue"
        }
    }

    /// Whether the current page shows a "Set up later" skip option
    private var showSkipOption: Bool {
        currentPage == 2 || currentPage == 3
    }

    // MARK: - Actions

    private func handlePrimaryAction() {
        if currentPage == 2 && !musicKitAuthorized {
            // Request MusicKit authorization on this page
            Task {
                let status = await musicService.requestAuthorization()
                if status == .authorized {
                    musicKitAuthorized = true
                    advanceToNextPage()
                } else {
                    // Denied or restricted — advance anyway to avoid trapping the user.
                    // They can still use the skip button or grant access later in Settings.
                    advanceToNextPage()
                }
            }
        } else if currentPage < totalPages - 1 {
            advanceToNextPage()
        } else {
            completeOnboarding()
        }
    }

    private func advanceToNextPage() {
        withAnimation(.easeInOut(duration: UIConstants.Animation.standard)) {
            currentPage += 1
        }
        logInfo("Onboarding advanced to page \(currentPage)", category: .ui)
    }

    private func handleSkip() {
        logInfo("User skipped onboarding page \(currentPage)", category: .ui)
        if currentPage < totalPages - 1 {
            advanceToNextPage()
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        logInfo("Onboarding completed. MusicKit authorized: \(musicKitAuthorized), HealthKit requested: \(healthKitRequested)", category: .ui)
        withAnimation(.easeInOut(duration: UIConstants.Animation.standard)) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingContainerView(
        hasCompletedOnboarding: .constant(false),
        musicService: MusicKitService()
    )
}
