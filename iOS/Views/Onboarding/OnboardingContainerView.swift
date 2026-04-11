//
//  OnboardingContainerView.swift
//  Resonance
//
//  Redesigned "3 Minutes to Wow" onboarding flow with 4 pages:
//    Page 1 - Brain Orb Welcome (10s): Animated brain orb + "Get Started"
//    Page 2 - Apple Music Connection (30s): Permission + inline library analysis
//    Page 3 - HealthKit Connection (30s): Permission with benefit rows
//    Page 4 - First Play (30s): HeartPulseRing sync + auto-selected song
//
//  Key design decisions:
//  - No separate LandingView or LibraryAnalysisView; both are merged inline.
//  - Library analysis starts immediately on MusicKit grant and continues
//    in the background across all subsequent pages.
//  - Programmatic page advancement (no swipe) to enforce sequencing.
//  - Page 4 transitions directly into the main TabView.
//

import SwiftUI
import MusicKit
import HealthKit

// MARK: - Onboarding Page

/// The four pages of the redesigned onboarding flow.
enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case musicConnection = 1
    case healthKit = 2
    case firstPlay = 3
}

// MARK: - Onboarding Container View

struct OnboardingContainerView: View {
    // MARK: - Properties

    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var musicService: MusicKitService

    @State private var currentPage: OnboardingPage = .welcome
    @State private var musicKitAuthorized = false
    @State private var musicKitDenied = false
    @State private var healthKitRequested = false
    @State private var analysisViewModel = OnboardingAnalysisViewModel()

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background: deep dark with blue undertone
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content (no swipe -- programmatic only)
                TabView(selection: $currentPage) {
                    BrainOrbWelcomePage(onGetStarted: advanceFromWelcome)
                        .tag(OnboardingPage.welcome)

                    MusicConnectionPage(
                        musicService: musicService,
                        analysisViewModel: analysisViewModel,
                        isAuthorized: $musicKitAuthorized,
                        isDenied: $musicKitDenied,
                        onContinue: advanceFromMusicConnection
                    )
                    .tag(OnboardingPage.musicConnection)

                    HealthKitConnectionPage(
                        healthKitRequested: $healthKitRequested,
                        onContinue: advanceFromHealthKit
                    )
                    .tag(OnboardingPage.healthKit)

                    FirstPlayPage(
                        analysisViewModel: analysisViewModel,
                        onEnterApp: completeOnboarding
                    )
                    .tag(OnboardingPage.firstPlay)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: UIConstants.Animation.standard), value: currentPage)
                // Disable swipe by intercepting gestures
                .highPriorityGesture(DragGesture())

                // Minimal page dots (no action button here; each page owns its CTA)
                pageDots
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            logInfo("Onboarding golden path started", category: .ui)
            musicKitAuthorized = musicService.authorizationStatus == .authorized
        }
        .onChange(of: musicService.authorizationStatus) { _, newStatus in
            musicKitAuthorized = newStatus == .authorized
            musicKitDenied = newStatus == .denied || newStatus == .restricted
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ResonanceColors.panelBg
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 12) {
            ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                RetroLEDIndicator(
                    isOn: page == currentPage,
                    color: page == currentPage ? ResonanceColors.ledGreen : ResonanceColors.metalMid,
                    size: 6
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Navigation Actions

    private func advanceFromWelcome() {
        withAnimation(.easeInOut(duration: UIConstants.Animation.standard)) {
            currentPage = .musicConnection
        }
        logInfo("Onboarding: Welcome -> Music Connection", category: .ui)
    }

    private func advanceFromMusicConnection() {
        withAnimation(.easeInOut(duration: UIConstants.Animation.standard)) {
            currentPage = .healthKit
        }
        logInfo("Onboarding: Music Connection -> HealthKit", category: .ui)
    }

    private func advanceFromHealthKit() {
        withAnimation(.easeInOut(duration: UIConstants.Animation.standard)) {
            currentPage = .firstPlay
        }
        logInfo("Onboarding: HealthKit -> First Play", category: .ui)
    }

    private func completeOnboarding() {
        logInfo(
            "Onboarding completed. MusicKit: \(musicKitAuthorized), HealthKit: \(healthKitRequested), "
            + "Songs analyzed: \(analysisViewModel.analyzedSongs)/\(analysisViewModel.totalSongs)",
            category: .ui
        )

        // Detach polling but let analysis continue in background
        analysisViewModel.detachFromOnboarding()

        withAnimation(.easeInOut(duration: UIConstants.Animation.slow)) {
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
    .preferredColorScheme(.dark)
}
