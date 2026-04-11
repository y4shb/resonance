//
//  RetroSliderPot.swift
//  Resonance
//
//  Linear fader control with DragGesture. Metallic fader cap slides
//  along a recessed slot with scale markings and inner shadow.
//

import SwiftUI

// MARK: - Retro Slider Pot

struct RetroSliderPot: View {
    @Binding var value: Double  // 0.0 to 1.0
    var orientation: Axis = .vertical
    var label: String = ""
    var showScale: Bool = true
    var length: CGFloat = 140

    @State private var hapticTrigger = 0
    private let slotWidth: CGFloat = 6
    private let capSize: CGSize = CGSize(width: 20, height: 12)

    var body: some View {
        VStack(spacing: 6) {
            if orientation == .vertical {
                verticalSlider
            } else {
                horizontalSlider
            }

            if !label.isEmpty {
                Text(label)
                    .retroEngravedLabel()
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.6), trigger: hapticTrigger)
        .accessibilityElement()
        .accessibilityLabel(label.isEmpty ? "Slider" : label)
        .accessibilityValue(String(format: "%.0f percent", value * 100))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.1)
            case .decrement: value = max(0, value - 0.1)
            @unknown default: break
            }
        }
    }

    // MARK: - Vertical Layout

    private var verticalSlider: some View {
        HStack(spacing: 6) {
            if showScale { scaleMarks(vertical: true) }

            ZStack(alignment: .bottom) {
                // Slot
                RoundedRectangle(cornerRadius: slotWidth / 2)
                    .fill(ResonanceColors.panelBg)
                    .frame(width: slotWidth, height: length)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

                // Fader cap
                faderCap
                    .offset(y: -CGFloat(value) * (length - capSize.height))
            }
            .frame(height: length)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let fraction = 1.0 - (gesture.location.y / length)
                        let newValue = max(0, min(1, fraction))
                        checkBoundsHaptic(newValue)
                        value = newValue
                    }
            )
        }
    }

    // MARK: - Horizontal Layout

    private var horizontalSlider: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .leading) {
                // Slot
                RoundedRectangle(cornerRadius: slotWidth / 2)
                    .fill(ResonanceColors.panelBg)
                    .frame(width: length, height: slotWidth)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

                // Fader cap (rotated for horizontal)
                faderCap
                    .offset(x: CGFloat(value) * (length - capSize.width))
            }
            .frame(width: length)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let fraction = gesture.location.x / length
                        let newValue = max(0, min(1, fraction))
                        checkBoundsHaptic(newValue)
                        value = newValue
                    }
            )

            if showScale { scaleMarks(vertical: false) }
        }
    }

    // MARK: - Fader Cap

    private var faderCap: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [ResonanceColors.metalLight, ResonanceColors.metalMid],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: capSize.width, height: capSize.height)
            .overlay(
                // Center groove
                Rectangle()
                    .fill(ResonanceColors.metalDark)
                    .frame(width: capSize.width * 0.6, height: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
    }

    // MARK: - Scale Marks

    private func scaleMarks(vertical: Bool) -> some View {
        let tickCount = 5
        return Group {
            if vertical {
                VStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { i in
                        if i > 0 { Spacer() }
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 6, height: 1)
                    }
                }
                .frame(height: length)
            } else {
                HStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { i in
                        if i > 0 { Spacer() }
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 6)
                    }
                }
                .frame(width: length)
            }
        }
    }

    // MARK: - Bounds Haptic

    private func checkBoundsHaptic(_ newValue: Double) {
        if (newValue <= 0 && value > 0) || (newValue >= 1 && value < 1) {
            hapticTrigger += 1
        }
    }
}

// MARK: - Preview

#Preview("Slider Pots") {
    @Previewable @State var v1 = 0.5
    @Previewable @State var h1 = 0.3

    HStack(spacing: 40) {
        RetroSliderPot(value: $v1, orientation: .vertical, label: "GAIN")
        VStack {
            RetroSliderPot(value: $h1, orientation: .horizontal, label: "PAN", length: 120)
        }
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
