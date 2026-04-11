//
//  RetroVUMeter.swift
//  Resonance
//
//  Semi-circular analog needle gauge with spring physics.
//  Canvas-drawn meter face with green/yellow/red zones and accent-colored needle.
//  Same GPU-composited Canvas pattern as CassettePlayerView reel animation.
//

import SwiftUI

// MARK: - Retro VU Meter

struct RetroVUMeter: View {
    let value: Double  // 0.0 to 1.0
    var label: String = "VU"
    var showPeakHold: Bool = false
    var size: CGFloat = 160

    @Environment(\.retroAccentColor) private var accentColor
    @State private var animatedValue: Double = 0
    @State private var peakValue: Double = 0
    @State private var peakDecayTimer: Timer?

    private let startAngle: Double = -135  // degrees from 12 o'clock
    private let endAngle: Double = -45
    private let meterHeight: CGFloat = 0.6  // height as fraction of width

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.85)
                let radius = min(canvasSize.width, canvasSize.height) * 0.7

                // Draw meter face (recessed panel)
                drawMeterFace(context: context, center: center, radius: radius, size: canvasSize)

                // Draw scale markings and zones
                drawScaleMarkings(context: context, center: center, radius: radius)

                // Draw needle
                let needleAngle = startAngle + (endAngle - startAngle) * animatedValue
                drawNeedle(context: context, center: center, radius: radius, angle: needleAngle)

                // Draw peak hold line
                if showPeakHold && peakValue > 0 {
                    let peakAngle = startAngle + (endAngle - startAngle) * peakValue
                    drawPeakHold(context: context, center: center, radius: radius, angle: peakAngle)
                }

                // Draw pivot pin
                drawPivot(context: context, center: center)

                // Draw "VU" label
                drawLabel(context: context, center: center, radius: radius)
            }
            .frame(width: size, height: size * meterHeight)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(ResonanceColors.panelBg)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.black.opacity(0.4), lineWidth: 1)
                    )
            )

            Text(label)
                .retroEngravedLabel()
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(RetroAnimation.needleBounce)) {
                animatedValue = max(0, min(1, newValue))
            }
            updatePeakHold(newValue)
        }
        .onAppear {
            animatedValue = max(0, min(1, value))
        }
        .onDisappear { peakDecayTimer?.invalidate(); peakDecayTimer = nil }
        .accessibilityElement()
        .accessibilityLabel("\(label) meter")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Drawing Methods

    private func drawMeterFace(context: GraphicsContext, center: CGPoint, radius: CGFloat, size: CGSize) {
        let facePath = Path { p in
            p.addArc(center: center, radius: radius * 0.95,
                     startAngle: .degrees(startAngle - 90), endAngle: .degrees(endAngle - 90),
                     clockwise: false)
            p.addLine(to: center)
            p.closeSubpath()
        }
        context.fill(facePath, with: .color(.white.opacity(0.08)))
    }

    private func drawScaleMarkings(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let tickCount = 11
        for i in 0..<tickCount {
            let fraction = Double(i) / Double(tickCount - 1)
            let angle = Angle.degrees(startAngle + (endAngle - startAngle) * fraction - 90)

            let innerRadius = radius * 0.75
            let outerRadius = radius * 0.9

            let innerPoint = CGPoint(
                x: center.x + innerRadius * cos(angle.radians),
                y: center.y + innerRadius * sin(angle.radians)
            )
            let outerPoint = CGPoint(
                x: center.x + outerRadius * cos(angle.radians),
                y: center.y + outerRadius * sin(angle.radians)
            )

            let tickColor: Color
            if fraction < 0.6 {
                tickColor = ResonanceColors.ledGreen.opacity(0.6)
            } else if fraction < 0.8 {
                tickColor = ResonanceColors.ledAmber.opacity(0.6)
            } else {
                tickColor = ResonanceColors.ledRed.opacity(0.6)
            }

            var tickPath = Path()
            tickPath.move(to: innerPoint)
            tickPath.addLine(to: outerPoint)
            context.stroke(tickPath, with: .color(tickColor), lineWidth: i % 5 == 0 ? 2 : 1)
        }
    }

    private func drawNeedle(context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double) {
        let needleAngle = Angle.degrees(angle - 90)
        let needleLength = radius * 0.85
        let tip = CGPoint(
            x: center.x + needleLength * cos(needleAngle.radians),
            y: center.y + needleLength * sin(needleAngle.radians)
        )

        var needlePath = Path()
        needlePath.move(to: center)
        needlePath.addLine(to: tip)
        context.stroke(needlePath, with: .color(accentColor), lineWidth: 1.5)
    }

    private func drawPeakHold(context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double) {
        let peakAngle = Angle.degrees(angle - 90)
        let innerR = radius * 0.7
        let outerR = radius * 0.85
        let innerPt = CGPoint(
            x: center.x + innerR * cos(peakAngle.radians),
            y: center.y + innerR * sin(peakAngle.radians)
        )
        let outerPt = CGPoint(
            x: center.x + outerR * cos(peakAngle.radians),
            y: center.y + outerR * sin(peakAngle.radians)
        )

        var peakPath = Path()
        peakPath.move(to: innerPt)
        peakPath.addLine(to: outerPt)
        context.stroke(peakPath, with: .color(accentColor.opacity(0.5)), lineWidth: 1)
    }

    private func drawPivot(context: GraphicsContext, center: CGPoint) {
        let pivotPath = Path(ellipseIn: CGRect(
            x: center.x - 3, y: center.y - 3, width: 6, height: 6
        ))
        context.fill(pivotPath, with: .color(ResonanceColors.screwChrome))
    }

    private func drawLabel(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let labelText = Text(label)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.3))
        context.draw(labelText, at: CGPoint(x: center.x, y: center.y - radius * 0.3))
    }

    // MARK: - Peak Hold

    private func updatePeakHold(_ newValue: Double) {
        guard showPeakHold else { return }
        let clamped = max(0, min(1, newValue))
        if clamped > peakValue {
            peakValue = clamped
            peakDecayTimer?.invalidate()
            peakDecayTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                withAnimation(.easeOut(duration: 0.5)) {
                    peakValue = 0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("VU Meter") {
    HStack(spacing: 20) {
        RetroVUMeter(value: 0.3, label: "ENERGY", size: 140)
        RetroVUMeter(value: 0.7, label: "VALENCE", showPeakHold: true, size: 140)
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
