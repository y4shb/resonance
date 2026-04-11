//
//  RetroLEDIndicator.swift
//  Resonance
//
//  Small LED dot with colored fill and soft glow bloom.
//  Recessed into panel with inner ring shadow.
//  Supports OFF, ON, and BLINK states.
//

import SwiftUI

// MARK: - Retro LED Indicator

struct RetroLEDIndicator: View {
    let isOn: Bool
    var color: Color = ResonanceColors.ledGreen
    var size: CGFloat = RetroDimensions.ledDefaultSize
    var blinkRate: Double? = nil

    @State private var blinkVisible = true
    @State private var blinkTimer: Timer?

    private var effectivelyOn: Bool {
        isOn && blinkVisible
    }

    var body: some View {
        ZStack {
            // Recessed well
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: size + 2, height: size + 2)

            // LED lens
            Circle()
                .fill(effectivelyOn ? color : ResonanceColors.metalDark)
                .frame(width: size, height: size)

            // Glow bloom when on
            if effectivelyOn {
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: size, height: size)
                    .blur(radius: size * 0.6)
            }
        }
        .animation(RetroAnimation.ledFade, value: effectivelyOn)
        .onAppear { startBlinkIfNeeded() }
        .onChange(of: blinkRate) { _, _ in startBlinkIfNeeded() }
        .onDisappear { blinkTimer?.invalidate(); blinkTimer = nil }
        .accessibilityHidden(true)
    }

    private func startBlinkIfNeeded() {
        blinkTimer?.invalidate()
        blinkTimer = nil

        guard let rate = blinkRate, rate > 0 else {
            blinkVisible = true
            return
        }
        let interval = 1.0 / (rate * 2)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            blinkVisible.toggle()
        }
    }
}

// MARK: - Preview

#Preview("LED States") {
    HStack(spacing: 20) {
        RetroLEDIndicator(isOn: false, color: .green)
        RetroLEDIndicator(isOn: true, color: ResonanceColors.ledGreen)
        RetroLEDIndicator(isOn: true, color: ResonanceColors.ledAmber)
        RetroLEDIndicator(isOn: true, color: ResonanceColors.ledRed)
        RetroLEDIndicator(isOn: true, color: .blue, blinkRate: 2)
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
