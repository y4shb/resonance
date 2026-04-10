//
//  HeartPulseRing.swift
//  Resonance
//
//  Vinyl platter ring overlay that beats at the user's heart rate.
//  Renders concentric groove-like rings around the vinyl record that
//  respond to BPM entrainment with the user's heart rate.
//
//  Three distinct visual states:
//    - Calm:         Subtle groove glow in album-art accent color
//    - Synced:       Bright groove illumination shifting toward gold
//    - Transitioning: Outward ripple across grooves when AI selects next track
//

import SwiftUI

// MARK: - Pulse State

/// The three visual states of the heart pulse ring.
enum PulseState: String {
    case calm
    case synced
    case transitioning
}

// MARK: - HeartPulseRing

struct HeartPulseRing: View {
    let heartRate: Double       // BPM from HealthKit
    let musicBPM: Double        // BPM of current track
    let accentColor: Color      // Derived from album art
    let reduceMotion: Bool
    let isTransitioning: Bool   // True when AI is selecting next track

    // MARK: - Animation State

    @State private var isPulsed = false
    @State private var previousPulseState: PulseState?
    @State private var syncHapticFired = false
    @State private var ripplePhase: CGFloat = 0
    @State private var rippleOpacity: CGFloat = 0

    // MARK: - Computed Properties

    /// How closely music BPM matches heart rate (0.0 - 1.0).
    private var entrainment: Double {
        guard heartRate > 0, musicBPM > 0 else { return 0 }
        let ratio = musicBPM / heartRate
        let directMatch = 1.0 - min(abs(ratio - 1.0), 1.0)
        let halfMatch   = 1.0 - min(abs(ratio - 0.5) * 2, 1.0)
        let doubleMatch = 1.0 - min(abs(ratio - 2.0), 1.0)
        return max(directMatch, halfMatch, doubleMatch)
    }

    /// Current visual state derived from inputs.
    private var pulseState: PulseState {
        if isTransitioning { return .transitioning }
        if entrainment >= 0.7 { return .synced }
        return .calm
    }

    /// Pulse duration derived from heart rate.
    private var pulseDuration: Double {
        guard heartRate > 30 else { return 1.0 }
        return 60.0 / heartRate
    }

    /// Ring color interpolated between accent (calm) and gold (synced).
    private var ringColor: Color {
        switch pulseState {
        case .calm, .transitioning:
            return accentColor
        case .synced:
            let blendFactor = min((entrainment - 0.7) / 0.3, 1.0)
            return interpolateColor(from: accentColor, to: HeartPulseRing.syncGold, factor: blendFactor)
        }
    }

    /// Base opacity for the groove glow.
    private var grooveGlowOpacity: Double {
        switch pulseState {
        case .calm:
            return 0.05 + entrainment * 0.15
        case .synced:
            return 0.25 + entrainment * 0.25
        case .transitioning:
            return 0.15
        }
    }

    /// Scale range for the pulse animation.
    private var pulseScaleHigh: CGFloat {
        switch pulseState {
        case .calm:          return 1.04
        case .synced:        return 1.02  // Tighter, more controlled
        case .transitioning: return 1.03
        }
    }

    /// Accessibility description of the current state.
    private var stateAccessibilityLabel: String {
        switch pulseState {
        case .calm:
            return "Platter ring, calm state"
        case .synced:
            return "Platter ring, synced with music"
        case .transitioning:
            return "Platter ring, AI selecting next track"
        }
    }

    // MARK: - Constants

    private static let syncGold = Color(red: 1.0, green: 0.84, blue: 0.35)
    private static let rippleDuration: Double = 1.5
    private static let grooveRingCount: Int = 6

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1: Ripple wave across grooves (transitioning state)
            rippleRing

            // Layer 2: Concentric groove rings (platter style)
            grooveRings

            // Layer 3: Inner glow ring (visible during entrainment or sync)
            innerGrooveGlow
        }
        .animation(
            reduceMotion ? .none :
                .easeInOut(duration: pulseDuration * 0.4)
                .repeatForever(autoreverses: true),
            value: isPulsed
        )
        .onAppear {
            if !reduceMotion {
                isPulsed = true
            }
        }
        .onChange(of: heartRate) {
            restartPulseAnimation()
        }
        .onChange(of: pulseState) { oldValue, newValue in
            handleStateTransition(from: oldValue, to: newValue)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stateAccessibilityLabel)
    }

    // MARK: - Groove Rings (Vinyl Platter Style)

    /// Concentric rings that mimic record grooves around the platter edge.
    /// Each ring has alternating opacity for depth, and the entire set
    /// pulses/glows based on entrainment state.
    private var grooveRings: some View {
        ForEach(0..<HeartPulseRing.grooveRingCount, id: \.self) { index in
            let ringProgress = Double(index) / Double(HeartPulseRing.grooveRingCount - 1)
            let ringScale = 1.0 + ringProgress * 0.12
            let isEvenRing = index % 2 == 0

            Circle()
                .stroke(
                    ringColor.opacity(
                        grooveGlowOpacity * (isEvenRing ? 1.0 : 0.5)
                    ),
                    lineWidth: isEvenRing ? 1.5 : 0.75
                )
                .scaleEffect(isPulsed ? ringScale * pulseScaleHigh : ringScale)
                .opacity(isPulsed ? 0.6 : 1.0)
        }
    }

    /// Inner glow that intensifies during sync — simulates groove specular highlight.
    @ViewBuilder
    private var innerGrooveGlow: some View {
        if entrainment > 0.5 || pulseState == .synced {
            let glowOpacity: Double = pulseState == .synced
                ? entrainment * 0.5
                : entrainment * 0.3
            let glowWidth: CGFloat = pulseState == .synced ? 3 : 2

            Circle()
                .stroke(ringColor.opacity(glowOpacity), lineWidth: glowWidth)
                .scaleEffect(isPulsed ? 1.03 : 1.0)
                .blur(radius: pulseState == .synced ? 8 : 5)
        }
    }

    /// Expanding ripple ring that sweeps outward across the grooves.
    @ViewBuilder
    private var rippleRing: some View {
        if pulseState == .transitioning && !reduceMotion {
            Circle()
                .stroke(accentColor.opacity(rippleOpacity), lineWidth: 2)
                .scaleEffect(1.0 + ripplePhase * 0.2)
                .blur(radius: ripplePhase * 4)
        }
    }

    // MARK: - State Transitions

    private func handleStateTransition(from oldState: PulseState, to newState: PulseState) {
        UIAccessibility.post(
            notification: .announcement,
            argument: stateAccessibilityLabel
        )

        switch newState {
        case .synced:
            if oldState != .synced {
                syncHapticFired = false
            }
            if !syncHapticFired {
                fireSyncHaptic()
                syncHapticFired = true
            }

        case .transitioning:
            startRipple()

        case .calm:
            syncHapticFired = false
            stopRipple()
        }
    }

    private func restartPulseAnimation() {
        guard !reduceMotion else { return }
        isPulsed = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            isPulsed = true
        }
    }

    // MARK: - Ripple Animation

    private func startRipple() {
        guard !reduceMotion else { return }
        ripplePhase = 0
        rippleOpacity = 0.5

        withAnimation(
            .easeOut(duration: HeartPulseRing.rippleDuration)
            .repeatForever(autoreverses: false)
        ) {
            ripplePhase = 1.0
            rippleOpacity = 0
        }
    }

    private func stopRipple() {
        withAnimation(.easeOut(duration: 0.3)) {
            ripplePhase = 0
            rippleOpacity = 0
        }
    }

    // MARK: - Haptic Feedback

    private func fireSyncHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Color Interpolation

    private func interpolateColor(from: Color, to: Color, factor: Double) -> Color {
        let f = min(max(factor, 0), 1)
        let fromComponents = UIColor(from).rgbaComponents
        let toComponents = UIColor(to).rgbaComponents

        return Color(
            red:   fromComponents.r + (toComponents.r - fromComponents.r) * f,
            green: fromComponents.g + (toComponents.g - fromComponents.g) * f,
            blue:  fromComponents.b + (toComponents.b - fromComponents.b) * f,
            opacity: fromComponents.a + (toComponents.a - fromComponents.a) * f
        )
    }
}

// MARK: - UIColor RGBA Helper

private extension UIColor {
    var rgbaComponents: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

// MARK: - Preview

#Preview("Calm") {
    HeartPulseRing(
        heartRate: 72,
        musicBPM: 120,
        accentColor: .blue,
        reduceMotion: false,
        isTransitioning: false
    )
    .frame(width: 200, height: 200)
    .padding()
    .background(.black)
}

#Preview("Synced") {
    HeartPulseRing(
        heartRate: 72,
        musicBPM: 72,
        accentColor: .blue,
        reduceMotion: false,
        isTransitioning: false
    )
    .frame(width: 200, height: 200)
    .padding()
    .background(.black)
}

#Preview("Transitioning") {
    HeartPulseRing(
        heartRate: 72,
        musicBPM: 72,
        accentColor: .blue,
        reduceMotion: false,
        isTransitioning: true
    )
    .frame(width: 200, height: 200)
    .padding()
    .background(.black)
}
