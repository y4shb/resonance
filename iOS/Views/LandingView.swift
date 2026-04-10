//
//  LandingView.swift
//  Resonance
//
//  Animated landing screen with glowing brain orb shown after onboarding
//  but before the first DJ session. Features a pulsing brain icon with
//  blue-purple gradient, app title, and a "Let's Resonate" call-to-action.
//
//  The brain orb uses matchedGeometryEffect to enable a smooth transition
//  into the main Now Playing artwork area.
//

import SwiftUI

// MARK: - Landing View

struct LandingView: View {
    // MARK: - Properties

    @Binding var hasStartedFirstSession: Bool
    var animationNamespace: Namespace.ID

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation state
    @State private var isPulsing = false
    @State private var isVisible = false
    @State private var buttonPressed = false
    @State private var vinylSpinDegrees: Double = 0
    @State private var vinylOpacity: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                brainOrbView
                    .padding(.bottom, 32)

                titleSection
                    .padding(.bottom, 12)

                subtitleSection

                Spacer()

                startButton
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 32)
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                ResonanceColors.adaptiveBackground(for: colorScheme),
                ResonanceColors.adaptiveSecondaryBackground(for: colorScheme),
                ResonanceColors.adaptiveBackground(for: colorScheme)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Brain Orb

    private var brainOrbView: some View {
        ZStack {
            // Outer pulse ring (ambient glow behind the record)
            Circle()
                .fill(ResonanceColors.accent.opacity(0.15))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            // Spinning vinyl record (spins up from 0 RPM)
            VinylRecordView(
                artwork: nil,
                diameter: 180,
                rotationDegrees: reduceMotion ? 0 : vinylSpinDegrees
            )
            .opacity(vinylOpacity)
            .matchedGeometryEffect(id: "heroArtwork", in: animationNamespace)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Resonance vinyl record")
    }

    // MARK: - Title

    private var titleSection: some View {
        Text("Resonance")
            .font(.largeTitle)
            .bold()
            .foregroundStyle(.primary)
    }

    // MARK: - Subtitle

    private var subtitleSection: some View {
        Text("Your AI-Powered DJ")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            handleStart()
        } label: {
            Text("Let's Resonate")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [ResonanceColors.accent, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(buttonPressed ? 0.96 : 1.0)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .accessibilityLabel("Start your first DJ session")
        .accessibilityHint("Transitions to the main app")
    }

    // MARK: - Actions

    private func startAnimations() {
        withAnimation(reduceMotion ? .none : .easeIn(duration: 0.6)) {
            isVisible = true
            vinylOpacity = 1.0
        }
        isPulsing = true

        // Spin-up animation: 0 → continuous rotation over 1.5s
        if !reduceMotion {
            withAnimation(.easeOut(duration: 1.5)) {
                vinylSpinDegrees = 360
            }
            // After initial spin-up, continue with continuous slow rotation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    vinylSpinDegrees = 720
                }
            }
        }
    }

    private func handleStart() {
        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
            buttonPressed = true
        }

        // Brief delay to show button press, then transition
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.15)) {
            withAnimation(reduceMotion ? .none : .spring(response: 0.8, dampingFraction: 0.85)) {
                hasStartedFirstSession = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var namespace
    @Previewable @State var started = false

    LandingView(
        hasStartedFirstSession: $started,
        animationNamespace: namespace
    )
    .preferredColorScheme(.dark)
}
