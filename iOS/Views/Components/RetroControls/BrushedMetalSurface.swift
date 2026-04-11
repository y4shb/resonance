//
//  BrushedMetalSurface.swift
//  Resonance
//
//  Container view with brushed aluminum texture, chrome edge highlights,
//  and optional corner screws. Used as the outer frame for every retro panel.
//

import SwiftUI

// MARK: - Brushed Metal Surface

struct BrushedMetalSurface<Content: View>: View {
    var cornerRadius: CGFloat = 12
    var showScrews: Bool = false
    let content: () -> Content

    var body: some View {
        ZStack {
            content()
        }
        .brushedMetal(cornerRadius: cornerRadius)
        .overlay {
            if showScrews {
                screwCorners
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
    }

    /// Chrome screw details at each corner.
    private var screwCorners: some View {
        GeometryReader { geo in
            let inset: CGFloat = 10
            let size = RetroDimensions.screwDiameter
            ForEach(0..<4, id: \.self) { corner in
                let x = corner % 2 == 0 ? inset : geo.size.width - inset
                let y = corner < 2 ? inset : geo.size.height - inset
                screwView(size: size)
                    .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
    }

    private func screwView(size: CGFloat) -> some View {
        ZStack {
            // Screw body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ResonanceColors.screwChrome, ResonanceColors.metalMid],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)

            // Cross slot
            Rectangle()
                .fill(ResonanceColors.metalDark)
                .frame(width: size * 0.6, height: 0.5)

            Rectangle()
                .fill(ResonanceColors.metalDark)
                .frame(width: 0.5, height: size * 0.6)
        }
    }
}

// MARK: - Preview

#Preview("Metal Surface") {
    BrushedMetalSurface(showScrews: true) {
        VStack {
            Text("CONFIGURATION")
                .retroEngravedLabel()
            Spacer()
        }
        .padding(20)
        .frame(width: 300, height: 200)
    }
    .padding(40)
    .background(Color.black)
}
