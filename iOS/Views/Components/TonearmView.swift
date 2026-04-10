//
//  TonearmView.swift
//  Resonance
//
//  Chrome tonearm with physically correct rotation, spring animation
//  on play/pause, and drag-to-seek gesture. Rendered as compound
//  SwiftUI shapes with metallic gradients and realistic shadows.
//

import SwiftUI

// MARK: - Tonearm View

struct TonearmView: View {
    // MARK: - Properties

    /// Current playback progress (0.0 – 1.0)
    let progress: Double

    /// Whether playback is active (tonearm on record vs. resting)
    let isPlaying: Bool

    /// Called when user finishes a drag-seek gesture with the computed progress
    var onSeek: ((Double) -> Void)?

    /// Called when user begins dragging the tonearm
    var onSeekStarted: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var isDragging = false
    @State private var dragAngle: Double = VinylConstants.tonearmRestingAngle

    // MARK: - Computed

    /// The tonearm angle derived from playback state
    private var targetAngle: Double {
        if isDragging {
            return dragAngle
        }
        if isPlaying {
            return VinylConstants.tonearmOuterGrooveAngle
                + progress * (VinylConstants.tonearmInnerGrooveAngle - VinylConstants.tonearmOuterGrooveAngle)
        }
        return VinylConstants.tonearmRestingAngle
    }

    /// Animation for the tonearm sweep
    private var sweepAnimation: Animation? {
        if reduceMotion || isDragging { return nil }
        if isPlaying {
            // Progress tracking: smooth linear per update
            return .linear(duration: 0.5)
        }
        // Play/pause sweep: spring with slight overshoot
        return VinylConstants.tonearmSpring
    }

    // MARK: - Body

    var body: some View {
        tonearmShape
            .rotationEffect(
                .degrees(targetAngle),
                anchor: VinylConstants.tonearmPivot
            )
            .animation(sweepAnimation, value: targetAngle)
            .shadow(
                color: VinylConstants.tonearmShadowColor,
                radius: VinylConstants.tonearmShadowRadius,
                x: 2,
                y: 2
            )
            .gesture(seekDragGesture)
            .accessibilityLabel("Tonearm")
            .accessibilityValue(
                isPlaying
                    ? "Playing at \(Int(progress * 100)) percent"
                    : "Resting"
            )
            .accessibilityHint("Drag to seek to a position in the track")
            .accessibilityAddTraits(.allowsDirectInteraction)
    }

    // MARK: - Tonearm Shape

    /// Compound shape: bearing base → arm tube → headshell → cartridge
    private var tonearmShape: some View {
        ZStack(alignment: .topTrailing) {
            // Arm tube: long tapered rectangle
            armTube
                .offset(x: -20, y: 18)

            // Bearing base at pivot point
            bearingBase
                .offset(x: -4, y: 4)

            // Headshell at the tip
            headshell
                .offset(x: -110, y: 145)

            // Cartridge/stylus
            cartridge
                .offset(x: -114, y: 170)
        }
        .frame(width: 160, height: 200)
    }

    // MARK: - Bearing Base

    private var bearingBase: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            VinylConstants.chromeLight,
                            VinylConstants.chromeDark
                        ],
                        center: UnitPoint(x: 0.4, y: 0.3),
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .frame(width: 24, height: 24)

            // Inner dark center
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Arm Tube

    private var armTube: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        VinylConstants.chromeLight,
                        VinylConstants.chromeDark,
                        VinylConstants.chromeLight.opacity(0.9)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 4, height: 140)
            .rotationEffect(.degrees(-8), anchor: .top)
    }

    // MARK: - Headshell

    private var headshell: some View {
        Trapezoid(topWidth: 6, bottomWidth: 14)
            .fill(
                LinearGradient(
                    colors: [
                        VinylConstants.chromeDark,
                        Color(white: 0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 14, height: 18)
            .rotationEffect(.degrees(-8))
    }

    // MARK: - Cartridge

    private var cartridge: some View {
        VStack(spacing: 0) {
            // Cartridge body
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(white: 0.1))
                .frame(width: 10, height: 8)

            // Stylus tip (silver point)
            Triangle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.7), Color(white: 0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 5)
        }
    }

    // MARK: - Seek Drag Gesture

    private var seekDragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    onSeekStarted?()
                    VinylSFXPlayer.shared.fireSelectionHaptic()
                }

                // Map drag translation to angle change
                // Vertical drag: up = toward outer groove, down = toward inner groove
                let verticalDelta = value.translation.height
                let sensitivity: Double = 0.08
                let rawAngle = VinylConstants.tonearmOuterGrooveAngle
                    + Double(verticalDelta) * sensitivity

                // Clamp to valid groove range
                dragAngle = min(
                    max(rawAngle, VinylConstants.tonearmOuterGrooveAngle),
                    VinylConstants.tonearmInnerGrooveAngle
                )
            }
            .onEnded { _ in
                // Map final angle to progress
                let range = VinylConstants.tonearmInnerGrooveAngle - VinylConstants.tonearmOuterGrooveAngle
                let seekProgress = (dragAngle - VinylConstants.tonearmOuterGrooveAngle) / range
                let clampedProgress = min(max(seekProgress, 0), 1)

                onSeek?(clampedProgress)
                VinylSFXPlayer.shared.playNeedleDrop()
                isDragging = false
            }
    }
}

// MARK: - Trapezoid Shape

/// A trapezoid with configurable top and bottom widths.
private struct Trapezoid: Shape {
    let topWidth: CGFloat
    let bottomWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let topInset = (rect.width - topWidth) / 2
        let bottomInset = (rect.width - bottomWidth) / 2

        var path = Path()
        path.move(to: CGPoint(x: topInset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - topInset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - bottomInset, y: rect.height))
        path.addLine(to: CGPoint(x: bottomInset, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Triangle Shape

/// A simple downward-pointing triangle for the stylus tip.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TonearmView(progress: 0.3, isPlaying: true)
    }
}
