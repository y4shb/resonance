//
//  RetroPushButton.swift
//  Resonance
//
//  Rectangular button with press depth animation.
//  Supports momentary (fires on release) and latching (stays pressed) modes.
//  Used for tab bar buttons, action buttons, and navigation.
//

import SwiftUI

// MARK: - Retro Push Button

struct RetroPushButton: View {
    let label: String
    var icon: String? = nil
    var action: () -> Void = {}
    var isLatching: Bool = false
    var isPressed: Bool = false  // External state for latching mode

    @State private var isMomentaryPressed = false
    @State private var pressTrigger = 0
    @State private var releaseTrigger = 0

    private var effectivelyPressed: Bool {
        isLatching ? isPressed : isMomentaryPressed
    }

    var body: some View {
        Button {
            if !isLatching {
                action()
            }
        } label: {
            VStack(spacing: 2) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(effectivelyPressed ? .white : .secondary)
            .frame(minWidth: 44, minHeight: 36)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: effectivelyPressed
                                ? [ResonanceColors.metalDark, ResonanceColors.metalDark.opacity(0.8)]
                                : [ResonanceColors.metalLight, ResonanceColors.metalMid],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            // Side edges for 3D depth
            .background(alignment: .bottom) {
                if !effectivelyPressed {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ResonanceColors.metalDark)
                        .frame(height: RetroDimensions.buttonProudHeight)
                        .offset(y: RetroDimensions.buttonProudHeight)
                }
            }
            .offset(y: effectivelyPressed ? RetroDimensions.buttonPressDepth : 0)
            .shadow(
                color: .black.opacity(effectivelyPressed ? 0.1 : 0.3),
                radius: effectivelyPressed ? 1 : 3,
                x: 0,
                y: effectivelyPressed ? 1 : 3
            )
            .animation(.spring(RetroAnimation.buttonPress), value: effectivelyPressed)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.7), trigger: pressTrigger)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: releaseTrigger)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isMomentaryPressed && !isLatching {
                        isMomentaryPressed = true
                        pressTrigger += 1
                    }
                }
                .onEnded { _ in
                    if !isLatching {
                        isMomentaryPressed = false
                        releaseTrigger += 1
                    }
                }
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(isLatching ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("Push Buttons") {
    HStack(spacing: 16) {
        RetroPushButton(label: "PLAY", icon: "play.fill")
        RetroPushButton(label: "STOP", icon: "stop.fill")
        RetroPushButton(label: "ENGAGE")
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
