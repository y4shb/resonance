//
//  BrushedMetalModifier.swift
//  Resonance
//
//  ViewModifier that applies a brushed aluminum surface texture to any view.
//  5-stop horizontal gradient with 2% white grain lines and chrome edge highlights.
//

import SwiftUI

// MARK: - Brushed Metal Modifier

struct BrushedMetalModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                ResonanceColors.metalLight,
                                ResonanceColors.metalMid,
                                ResonanceColors.metalLight.opacity(0.9),
                                ResonanceColors.metalMid,
                                ResonanceColors.metalLight.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        // Grain texture: thin horizontal lines
                        grainOverlay
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    )
                    .overlay(
                        // Chrome edge highlights
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.08),
                                        Color.clear,
                                        Color.black.opacity(0.15)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }

    /// Horizontal grain lines at 1pt intervals.
    private var grainOverlay: some View {
        Canvas { context, size in
            let lineCount = Int(size.height / 2)
            for i in 0..<lineCount {
                let y = CGFloat(i) * 2
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.white.opacity(0.02)), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies brushed metal surface texture to the view.
    func brushedMetal(cornerRadius: CGFloat = 12) -> some View {
        modifier(BrushedMetalModifier(cornerRadius: cornerRadius))
    }
}
