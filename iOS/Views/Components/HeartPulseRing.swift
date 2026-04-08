//
//  HeartPulseRing.swift
//  Resonance
//
//  Pulsing ring overlay that beats at the user's heart rate.
//  Three distinct visual states:
//    - Calm:         Gentle breathing glow in album-art accent color
//    - Synced:       Bright, tight pulse shifting toward gold
//    - Transitioning: Outward ripple effect when AI is selecting next track
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
            // Blend toward gold based on how far above the 0.7 threshold we are.
            // At entrainment 0.7 we start blending; at 1.0 we are fully gold.
            let blendFactor = min((entrainment - 0.7) / 0.3, 1.0)
            return interpolateColor(from: accentColor, to: HeartPulseRing.syncGold, factor: blendFactor)
        }
    }

    /// Base opacity for the ring stroke.
    private var ringOpacity: Double {
        switch pulseState {
        case .calm:
            return 0.15 + entrainment * 0.35
        case .synced:
            return 0.55 + entrainment * 0.25   // Brighter when synced
        case .transitioning:
            return 0.35
        }
    }

    /// Scale range for the pulse animation.
    private var pulseScaleHigh: CGFloat {
        switch pulseState {
        case .calm:        return 1.08
        case .synced:      return 1.03  // Tighter, more controlled pulse
        case .transitioning: return 1.05
        }
    }

    /// Accessibility description of the current state.
    private var stateAccessibilityLabel: String {
        switch pulseState {
        case .calm:
            return "Heart pulse ring, calm state"
        case .synced:
            return "Heart pulse ring, synced with music"
        case .transitioning:
            return "Heart pulse ring, AI selecting next track"
        }
    }

    // MARK: - Constants

    /// The gold/warm color used at full sync.
    private static let syncGold = Color(red: 1.0, green: 0.84, blue: 0.35)

    /// Duration of the ripple expand/fade animation.
    private static let rippleDuration: Double = 1.5

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1: Ripple ring (transitioning state only)
            rippleRing

            // Layer 2: Outer pulse ring
            outerPulseRing

            // Layer 3: Inner glow ring (visible during entrainment or sync)
            innerGlowRing
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

    // MARK: - Ring Layers

    /// Outer stroke circle that pulses with the heartbeat.
    private var outerPulseRing: some View {
        Circle()
            .stroke(
                ringColor.opacity(ringOpacity),
                lineWidth: isPulsed ? 2 : 4
            )
            .scaleEffect(isPulsed ? pulseScaleHigh : 1.0)
            .opacity(isPulsed ? 0.3 : ringOpacity)
    }

    /// Inner glow circle, more prominent in synced state.
    @ViewBuilder
    private var innerGlowRing: some View {
        if entrainment > 0.5 || pulseState == .synced {
            let glowOpacity: Double = pulseState == .synced
                ? entrainment * 0.6   // More prominent in sync
                : entrainment * 0.4
            let glowWidth: CGFloat = pulseState == .synced ? 3 : 2

            Circle()
                .stroke(ringColor.opacity(glowOpacity), lineWidth: glowWidth)
                .scaleEffect(isPulsed ? 1.04 : 1.0)
                .blur(radius: pulseState == .synced ? 6 : 4)
        }
    }

    /// Expanding ripple ring that fades as it grows (transitioning state).
    @ViewBuilder
    private var rippleRing: some View {
        if pulseState == .transitioning && !reduceMotion {
            Circle()
                .stroke(accentColor.opacity(rippleOpacity), lineWidth: 2)
                .scaleEffect(1.0 + ripplePhase * 0.3)
                .blur(radius: ripplePhase * 3)
        }
    }

    // MARK: - State Transitions

    /// Handles visual and haptic responses to state changes.
    private func handleStateTransition(from oldState: PulseState, to newState: PulseState) {
        // Announce state change to VoiceOver
        UIAccessibility.post(
            notification: .announcement,
            argument: stateAccessibilityLabel
        )

        switch newState {
        case .synced:
            // Fire haptic once on entering sync (not continuously)
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

    /// Restarts the pulse animation when heart rate changes significantly.
    private func restartPulseAnimation() {
        guard !reduceMotion else { return }
        isPulsed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isPulsed = true
        }
    }

    // MARK: - Ripple Animation

    /// Launches the repeating ripple expand-and-fade cycle.
    private func startRipple() {
        guard !reduceMotion else { return }
        // Reset to start
        ripplePhase = 0
        rippleOpacity = 0.6

        // Animate outward expansion with fade
        withAnimation(
            .easeOut(duration: HeartPulseRing.rippleDuration)
            .repeatForever(autoreverses: false)
        ) {
            ripplePhase = 1.0
            rippleOpacity = 0
        }
    }

    /// Stops the ripple and resets its state.
    private func stopRipple() {
        withAnimation(.easeOut(duration: 0.3)) {
            ripplePhase = 0
            rippleOpacity = 0
        }
    }

    // MARK: - Haptic Feedback

    /// Fires a single light impact when entering the synced state.
    private func fireSyncHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Color Interpolation

    /// Linearly interpolates between two SwiftUI Colors in RGB space.
    /// `factor` is clamped to 0...1 where 0 = `from`, 1 = `to`.
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
    /// Extracts RGBA components as Doubles in [0, 1].
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
