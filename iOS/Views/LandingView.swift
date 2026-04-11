//
//  LandingView.swift
//  Resonance
//
//  Retro power-on boot sequence landing screen shown after onboarding
//  but before the first DJ session. Features a typewriter boot LCD panel,
//  flanking VU meters, and a retro ENGAGE push button.
//
//  The boot LED uses matchedGeometryEffect to enable a smooth transition
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
    @State private var isVisible = false
    @State private var bootText = ""
    @State private var showMeters = false
    @State private var showButton = false
    @State private var meterValue: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            ResonanceColors.panelBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Boot LED
                RetroLEDIndicator(isOn: isVisible, color: ResonanceColors.ledGreen, size: 12)
                    .padding(.bottom, 24)
                    .matchedGeometryEffect(id: "heroArtwork", in: animationNamespace)

                // Boot LCD panel
                RetroLCDPanel(title: "SYSTEM STATUS") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bootText)
                            .font(RetroTypography.lcdBody)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

                // Flanking VU meters
                if showMeters {
                    HStack(spacing: 20) {
                        RetroVUMeter(value: meterValue, label: "SYS", size: 100)
                        RetroVUMeter(value: meterValue * 0.8, label: "BIO", size: 100)
                    }
                    .padding(.bottom, 24)
                    .transition(.opacity)
                }

                Spacer()

                // Engage button
                if showButton {
                    RetroPushButton(label: "ENGAGE", icon: "power") {
                        handleStart()
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 60)
                }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            startBootSequence()
        }
    }

    // MARK: - Boot Sequence

    private func startBootSequence() {
        let bootLines = [
            "RESONANCE AI DJ SYSTEM",
            "v2.0 \u{25A0}\u{25A0}\u{25A0}\u{25A0}\u{25A0}\u{25A0}\u{25A0}\u{25A0} OK",
            "INITIALIZING NEURAL ENGINE...",
            "BIOMETRIC LINK: CONNECTED",
            "LIBRARY SCAN: 1,247 TRACKS",
            "STATUS: READY"
        ]

        if reduceMotion {
            // Skip animation, show everything immediately
            isVisible = true
            bootText = bootLines.joined(separator: "\n")
            showMeters = true
            meterValue = 0.7
            showButton = true
            return
        }

        withAnimation(.easeIn(duration: 0.3)) {
            isVisible = true
        }

        // Typewriter boot text
        var delay: Double = 0.5
        for line in bootLines {
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

        // Show meters
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(RetroAnimation.needleBounce)) {
                showMeters = true
                meterValue = 0.7
            }
        }

        // Show button
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) {
            withAnimation(.spring(RetroAnimation.buttonPress)) {
                showButton = true
            }
        }
    }

    // MARK: - Actions

    private func handleStart() {
        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
            // Brief visual feedback handled by RetroPushButton internally
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
