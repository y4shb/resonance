//
//  RetroLCDPanel.swift
//  Resonance
//
//  Recessed rectangular display panel with dark blue-black interior,
//  monospaced accent-tinted content, and horizontal scanline texture.
//

import SwiftUI

// MARK: - Retro LCD Panel

struct RetroLCDPanel<Content: View>: View {
    var title: String? = nil
    var width: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.retroAccentColor) private var accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .retroEngravedLabel()
            }

            ZStack {
                // Recessed panel background
                RoundedRectangle(cornerRadius: 4)
                    .fill(ResonanceColors.panelBg)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.black.opacity(0.4), lineWidth: 1)
                    )

                // Content with accent tint
                content()
                    .foregroundStyle(ResonanceColors.phosphorBlue(accentColor))

                // Scanline overlay
                scanlineOverlay
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .allowsHitTesting(false)
            }
            .frame(width: width)
        }
    }

    /// Horizontal scanline texture: 1px lines at 50% opacity, 2px apart.
    private var scanlineOverlay: some View {
        Canvas { context, size in
            let lineCount = Int(size.height / 2)
            for i in 0..<lineCount {
                let y = CGFloat(i) * 2
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.black.opacity(0.50)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Preview

#Preview("LCD Panel") {
    VStack(spacing: 20) {
        RetroLCDPanel(title: "CURRENT STATE") {
            Text("ENERGY: 0.72")
                .font(RetroTypography.lcdBody)
                .padding(12)
        }

        RetroLCDPanel {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI RECOMMENDS:")
                    .font(RetroTypography.lcdCaption)
                Text("CALM -> FOCUS (12 TRACKS)")
                    .font(RetroTypography.lcdTitle)
            }
            .padding(12)
        }
    }
    .padding(40)
    .background(ResonanceColors.metalDark)
}
