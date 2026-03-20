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
            // Outer pulse ring
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            // Inner glow
            Circle()
                .fill(Color.purple.opacity(0.1))
                .frame(width: 160, height: 160)
                .blur(radius: 30)

            // Brain icon with gradient
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .matchedGeometryEffect(id: "heroArtwork", in: animationNamespace)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Resonance brain icon")
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
                                colors: [.blue, .purple],
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
        }
        isPulsing = true
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
