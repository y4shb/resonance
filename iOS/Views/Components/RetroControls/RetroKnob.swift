//
//  RetroKnob.swift
//  Resonance
//
//  3D cylindrical rotary control with RotationGesture.
//  Canvas-drawn knob body with radial gradient for 3D cylinder illusion.
//  Spring snaps to configurable detent positions with haptic feedback.
//

import SwiftUI

// MARK: - Retro Knob

struct RetroKnob: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var detents: Int? = nil
    var label: String = ""
    var size: CGFloat = 60

    @Environment(\.retroAccentColor) private var accentColor
    @State private var rotationAngle: Angle = .zero
    @State private var lastDetentIndex: Int = -1
    @State private var hapticTrigger = 0

    /// Maps value to rotation: 0.0 = -135deg, 1.0 = 135deg (270deg sweep)
    private let sweepDegrees: Double = 270
    private let startDegrees: Double = -135

    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var currentAngleDegrees: Double {
        startDegrees + normalizedValue * sweepDegrees
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Recess well
                Circle()
                    .fill(ResonanceColors.panelBg)
                    .frame(width: size + 8, height: size + 8)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

                // Detent markers around the recess
                detentMarkers

                // Knob body
                knobBody

                // Pointer line
                pointerLine
            }
            .frame(width: size + 16, height: size + 16)
            .gesture(dragRotation)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: hapticTrigger)

            if !label.isEmpty {
                Text(label)
                    .retroEngravedLabel()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(label.isEmpty ? "Rotary control" : label)
        .accessibilityValue(String(format: "%.0f percent", normalizedValue * 100))
        .accessibilityAdjustableAction { direction in
            let step = 1.0 / Double(detents ?? 10)
            switch direction {
            case .increment: value = min(range.upperBound, value + step * (range.upperBound - range.lowerBound))
            case .decrement: value = max(range.lowerBound, value - step * (range.upperBound - range.lowerBound))
            @unknown default: break
            }
        }
    }

    // MARK: - Knob Body (Canvas)

    private var knobBody: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2

            // 3D cylinder illusion via radial gradient
            let knobPath = Path(ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))

            context.fill(knobPath, with: .radialGradient(
                Gradient(colors: [
                    ResonanceColors.metalLight,
                    ResonanceColors.metalMid,
                    ResonanceColors.metalDark
                ]),
                center: CGPoint(x: center.x - radius * 0.2, y: center.y - radius * 0.2),
                startRadius: 0,
                endRadius: radius
            ))

            // Highlight ring
            context.stroke(knobPath, with: .color(accentColor.opacity(0.3)), lineWidth: 1.5)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Pointer Line

    private var pointerLine: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: size * 0.35)
            .offset(y: -size * 0.15)
            .rotationEffect(.degrees(currentAngleDegrees))
    }

    // MARK: - Detent Markers

    private var detentMarkers: some View {
        ForEach(0..<(detents ?? 10) + 1, id: \.self) { i in
            let fraction = Double(i) / Double(detents ?? 10)
            let angle = startDegrees + fraction * sweepDegrees
            let markerRadius = (size + 8) / 2 + 4

            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 2, height: 2)
                .offset(y: -markerRadius)
                .rotationEffect(.degrees(angle))
        }
    }

    // MARK: - Drag Gesture (maps vertical drag to rotation)

    private var dragRotation: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gestureValue in
                // Vertical drag: up = increase, down = decrease
                let delta = -gestureValue.translation.height / 200
                let newNormalized = max(0, min(1, normalizedValue + delta))
                let newValue = range.lowerBound + newNormalized * (range.upperBound - range.lowerBound)

                if let detentCount = detents {
                    // Snap to nearest detent
                    let step = (range.upperBound - range.lowerBound) / Double(detentCount)
                    let snapped = (newValue / step).rounded() * step
                    let detentIndex = Int((snapped - range.lowerBound) / step)

                    if detentIndex != lastDetentIndex {
                        lastDetentIndex = detentIndex
                        hapticTrigger += 1
                    }

                    withAnimation(.spring(RetroAnimation.knobRotation)) {
                        value = max(range.lowerBound, min(range.upperBound, snapped))
                    }
                } else {
                    value = max(range.lowerBound, min(range.upperBound, newValue))
                }
            }
    }
}

// MARK: - Preview

#Preview("Knobs") {
    @Previewable @State var energy = 0.5
    @Previewable @State var valence = 0.7

    HStack(spacing: 30) {
        RetroKnob(value: $energy, detents: 10, label: "ENERGY")
        RetroKnob(value: $valence, detents: 10, label: "VALENCE")
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
