//
//  RetroToggleSwitch.swift
//  Resonance
//
//  3D rectangular rocker switch in metal bezel with adjacent LED.
//  ON tilts up-right, OFF tilts down-left via 3D rotation.
//

import SwiftUI

// MARK: - Retro Toggle Switch

struct RetroToggleSwitch: View {
    @Binding var isOn: Bool
    var label: String = ""
    var ledColor: Color = ResonanceColors.ledGreen

    @State private var hapticTrigger = 0

    var body: some View {
        HStack(spacing: 10) {
            if !label.isEmpty {
                Text(label)
                    .retroEngravedLabel()
            }

            // Switch body
            Button {
                withAnimation(.spring(RetroAnimation.switchFlip)) {
                    isOn.toggle()
                }
                hapticTrigger += 1
            } label: {
                ZStack {
                    // Metal bezel
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ResonanceColors.metalDark)
                        .frame(width: 32, height: 18)

                    // Rocker
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [ResonanceColors.metalLight, ResonanceColors.metalMid],
                                startPoint: isOn ? .topTrailing : .bottomLeading,
                                endPoint: isOn ? .bottomLeading : .topTrailing
                            )
                        )
                        .frame(width: 28, height: 14)
                        .overlay(
                            Text(isOn ? "ON" : "OFF")
                                .font(.system(size: 5, weight: .bold, design: .monospaced))
                                .foregroundStyle(ResonanceColors.metalDark)
                        )
                        .rotation3DEffect(
                            .degrees(isOn ? RetroDimensions.switchRotationAngle : -RetroDimensions.switchRotationAngle),
                            axis: (x: 1, y: 0, z: 0),
                            perspective: 0.3
                        )
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            // Adjacent LED
            RetroLEDIndicator(isOn: isOn, color: ledColor)
        }
        .accessibilityElement()
        .accessibilityLabel(label.isEmpty ? "Toggle" : label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        .accessibilityAction { isOn.toggle() }
    }
}

// MARK: - Preview

#Preview("Toggle Switches") {
    @Previewable @State var s1 = true
    @Previewable @State var s2 = false

    VStack(spacing: 20) {
        RetroToggleSwitch(isOn: $s1, label: "HEART RATE")
        RetroToggleSwitch(isOn: $s2, label: "SLEEP DATA", ledColor: ResonanceColors.ledAmber)
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
