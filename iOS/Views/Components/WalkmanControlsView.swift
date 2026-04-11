//
//  WalkmanControlsView.swift
//  Resonance
//
//  Realistic mechanical Walkman button row with interlocking press states.
//  Buttons physically depress and stay down (PLAY, PAUSE) or are momentary
//  (STOP, REW, FF), replicating real cassette player button linkage mechanics.
//
//  Button layout: [◀◀ REW] [▶ PLAY] [▶▶ FF] [■ STOP] [❙❙ PAUSE]
//
//  Pressing PLAY locks it down and releases STOP/PAUSE.
//  Pressing STOP releases ALL buttons (pops everything up).
//  Pressing PAUSE toggles its half-press state.
//  REW and FF are momentary (held while pressing).
//

import SwiftUI

// MARK: - Walkman Button State

/// Represents which buttons are currently in the "pressed/locked" position.
struct WalkmanButtonState {
    var playLocked: Bool = false
    var pauseLocked: Bool = false

    /// Pressing PLAY locks it, releases PAUSE
    mutating func pressPlay() {
        playLocked = true
        pauseLocked = false
    }

    /// Pressing STOP releases everything
    mutating func pressStop() {
        playLocked = false
        pauseLocked = false
    }

    /// Pressing PAUSE toggles it; if we were playing, pause stays down
    mutating func pressPause() {
        pauseLocked.toggle()
    }
}

// MARK: - Walkman Controls View

struct WalkmanControlsView: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onStop: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let accentColor: Color

    @State private var buttonState = WalkmanButtonState()
    @State private var rewPressed = false
    @State private var ffPressed = false
    @State private var stopFlash = false

    // Haptic triggers
    @State private var hapticTrigger = 0

    var body: some View {
        HStack(spacing: 4) {
            // REW ◀◀
            mechanicalButton(
                symbol: "backward.end.fill",
                label: "Rewind",
                isLocked: false,
                isPressed: rewPressed,
                width: 52
            ) {
                rewPressed = true
                triggerHaptic(.medium)
                onPrevious()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    rewPressed = false
                }
            }

            // PLAY ▶
            mechanicalButton(
                symbol: "play.fill",
                label: "Play",
                isLocked: buttonState.playLocked && isPlaying,
                isPressed: false,
                width: 58
            ) {
                triggerHaptic(.heavy)
                if !isPlaying {
                    buttonState.pressPlay()
                }
                onPlayPause()
            }

            // FF ▶▶
            mechanicalButton(
                symbol: "forward.end.fill",
                label: "Fast Forward",
                isLocked: false,
                isPressed: ffPressed,
                width: 52
            ) {
                ffPressed = true
                triggerHaptic(.medium)
                onNext()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    ffPressed = false
                }
            }

            // STOP ■
            mechanicalButton(
                symbol: "stop.fill",
                label: "Stop",
                isLocked: false,
                isPressed: stopFlash,
                width: 52
            ) {
                triggerHaptic(.rigid)
                buttonState.pressStop()
                stopFlash = true
                onStop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    stopFlash = false
                }
            }

            // PAUSE ❙❙
            mechanicalButton(
                symbol: "pause.fill",
                label: "Pause",
                isLocked: buttonState.pauseLocked && !isPlaying,
                isPressed: false,
                width: 52
            ) {
                triggerHaptic(.medium)
                buttonState.pressPause()
                onPlayPause()
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                buttonState.playLocked = true
                buttonState.pauseLocked = false
            } else {
                buttonState.playLocked = false
                // Don't force pauseLocked here — let pressStop() and
                // pressPause() manage it so STOP correctly releases all buttons
            }
        }
    }

    // MARK: - Mechanical Button (3D Front/Side View)

    /// Each button has three visible faces when viewed from the front:
    /// - Top surface: catches light (lighter gradient), shrinks when pressed
    /// - Front face: main area with icon
    /// - Bottom edge: underside shadow, disappears when pressed
    /// Together these create a physical protruding button seen from slightly below.
    private func mechanicalButton(
        symbol: String,
        label: String,
        isLocked: Bool,
        isPressed: Bool,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        let depressed = isLocked || isPressed
        let frontHeight: CGFloat = 34
        let topBevelHeight: CGFloat = depressed ? 2 : 7
        let bottomEdgeHeight: CGFloat = depressed ? 1 : 4

        return Button(action: action) {
            VStack(spacing: 0) {
                // Top surface (visible because viewing from below the top edge)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: depressed
                                ? [Color(red: 0.10, green: 0.10, blue: 0.12)]
                                : [
                                    Color(red: 0.26, green: 0.26, blue: 0.30),
                                    Color(red: 0.19, green: 0.19, blue: 0.23)
                                  ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: topBevelHeight)

                // Front face (main button area with icon)
                ZStack {
                    // Face gradient
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: depressed
                                    ? [
                                        Color(red: 0.08, green: 0.08, blue: 0.10),
                                        Color(red: 0.06, green: 0.06, blue: 0.08)
                                    ]
                                    : [
                                        Color(red: 0.17, green: 0.17, blue: 0.21),
                                        Color(red: 0.12, green: 0.12, blue: 0.15)
                                    ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Icon
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(
                            depressed ? accentColor : Color.white.opacity(0.7)
                        )

                    // Accent edge glow when locked
                    if depressed {
                        Rectangle()
                            .stroke(accentColor.opacity(0.3), lineWidth: 0.5)
                            .blur(radius: 1)
                    }
                }
                .frame(height: frontHeight)

                // Bottom edge (underside, in shadow)
                Rectangle()
                    .fill(Color(red: 0.04, green: 0.04, blue: 0.06))
                    .frame(height: bottomEdgeHeight)
            }
            .frame(width: width)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 3,
                    bottomLeadingRadius: 1,
                    bottomTrailingRadius: 1,
                    topTrailingRadius: 3
                )
            )
            .overlay(
                // Side edge highlights (left catches light, right in shadow)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(depressed ? 0.02 : 0.07))
                        .frame(width: 0.5)
                    Spacer()
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 0.5)
                }
            )
            .shadow(
                color: .black.opacity(depressed ? 0.3 : 0.6),
                radius: depressed ? 1 : 5,
                x: 0,
                y: depressed ? 1 : 5
            )
            .offset(y: depressed ? 3 : 0)
            .animation(
                .spring(response: 0.15, dampingFraction: 0.6),
                value: depressed
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(depressed ? [.isSelected] : [])
    }

    // MARK: - Haptics

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Walkman Progress Bar

/// Minimal tape-counter-style progress bar styled to match the Walkman aesthetic.
struct WalkmanProgressView: View {
    @Binding var progress: Double
    let currentTime: TimeInterval
    let duration: TimeInterval
    let accentColor: Color
    let onScrubStart: () -> Void
    let onScrubEnd: (Double) -> Void

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            // Progress track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 3)

                    // Filled portion
                    Capsule()
                        .fill(accentColor.opacity(0.6))
                        .frame(
                            width: max(0, geo.size.width * CGFloat(isScrubbing ? scrubValue : progress)),
                            height: 3
                        )

                    // Knob
                    Circle()
                        .fill(accentColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: accentColor.opacity(0.5), radius: 4)
                        .offset(
                            x: max(0, geo.size.width * CGFloat(isScrubbing ? scrubValue : progress) - 5)
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isScrubbing {
                                isScrubbing = true
                                scrubValue = progress
                                onScrubStart()
                            }
                            scrubValue = max(0, min(1, Double(value.location.x / geo.size.width)))
                        }
                        .onEnded { _ in
                            isScrubbing = false
                            onScrubEnd(scrubValue)
                        }
                )
            }
            .frame(height: 10)

            // Time display (LCD style)
            HStack {
                Text(formatTime(isScrubbing ? scrubValue * duration : currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(accentColor.opacity(0.7))
                    .monospacedDigit()

                Spacer()

                Text(formatTime(duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .monospacedDigit()
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - LED Indicator

/// Small glowing LED dot that changes color based on playback state.
struct WalkmanLEDView: View {
    let isPlaying: Bool
    let accentColor: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var glowing = false

    var body: some View {
        Circle()
            .fill(ledColor)
            .frame(width: 5, height: 5)
            .shadow(color: ledColor.opacity(0.8), radius: glowing ? 6 : 3)
            .shadow(color: ledColor.opacity(0.4), radius: glowing ? 10 : 5)
            .animation(
                reduceMotion ? .none :
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: glowing
            )
            .onAppear { glowing = true }
            .onChange(of: isPlaying) { _, _ in
                glowing = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    glowing = true
                }
            }
            .accessibilityLabel(isPlaying ? "Playing" : "Paused")
    }

    private var ledColor: Color {
        isPlaying ? accentColor : Color(red: 1.0, green: 0.7, blue: 0.2) // Amber when paused
    }
}

// MARK: - Preview

#Preview("Walkman Controls - Playing") {
    ZStack {
        Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
        VStack(spacing: 24) {
            WalkmanControlsView(
                isPlaying: true,
                onPlayPause: {},
                onStop: {},
                onPrevious: {},
                onNext: {},
                accentColor: ResonanceColors.accent
            )

            HStack(spacing: 8) {
                WalkmanLEDView(isPlaying: true, accentColor: ResonanceColors.accent)
                Text("RESONANCE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(ResonanceColors.accent.opacity(0.5))
                    .tracking(2)
            }
        }
    }
}

#Preview("Walkman Controls - Paused") {
    ZStack {
        Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
        WalkmanControlsView(
            isPlaying: false,
            onPlayPause: {},
            onStop: {},
            onPrevious: {},
            onNext: {},
            accentColor: .purple
        )
    }
}
