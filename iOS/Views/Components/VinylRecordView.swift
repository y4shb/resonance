//
//  VinylRecordView.swift
//  Resonance
//
//  Hyper-realistic spinning vinyl record disc with concentric groove
//  rings, album-art label, center spindle, and specular highlight.
//  Uses Canvas + .drawingGroup() for Metal-accelerated groove rendering.
//

import SwiftUI
import MusicKit

// MARK: - Vinyl Record View

struct VinylRecordView: View {
    // MARK: - Properties

    /// MusicKit artwork for the circular label center
    let artwork: Artwork?

    /// Total record diameter in points
    var diameter: CGFloat = VinylConstants.recordDiameterLarge

    /// Current rotation angle in degrees (driven by VinylRotationController)
    var rotationDegrees: Double = 0

    /// Base disc color (customizable for colored vinyl variants)
    var vinylColor: Color = VinylConstants.vinylBlack

    /// Whether this is a mini player record (simplified grooves)
    var isMini: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed

    private var labelDiameter: CGFloat {
        diameter * VinylConstants.labelRatio
    }

    private var spindleDiameter: CGFloat {
        diameter * VinylConstants.spindleRatio
    }

    private var grooveCount: Int {
        isMini ? VinylConstants.grooveCountMini : VinylConstants.grooveCount
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1: Base disc with radial sheen
            baseDisc

            // Layer 2: Groove rings (Canvas for performance)
            grooveCanvas
                .drawingGroup()

            // Layer 3: Album art label
            labelView

            // Layer 4: Center spindle
            spindleView

            // Layer 5: Surface reflection overlay
            surfaceReflection
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(reduceMotion ? 0 : rotationDegrees))
        .shadow(
            color: VinylConstants.recordShadowColor,
            radius: isMini ? 4 : VinylConstants.recordShadowRadius,
            x: 0,
            y: isMini ? 2 : VinylConstants.recordShadowY
        )
        .accessibilityLabel("Vinyl record")
    }

    // MARK: - Layer 1: Base Disc

    private var baseDisc: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        vinylColor.opacity(1.0),
                        vinylColor.opacity(0.92),
                        vinylColor.opacity(0.96),
                        vinylColor
                    ],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: diameter * 0.05,
                    endRadius: diameter * 0.55
                )
            )
            .frame(width: diameter, height: diameter)
    }

    // MARK: - Layer 2: Groove Rings

    private var grooveCanvas: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let innerRadius = labelDiameter / 2 + 2
            let outerRadius = diameter / 2 - 2
            let grooveSpacing = (outerRadius - innerRadius) / CGFloat(grooveCount)

            for i in 0..<grooveCount {
                let radius = innerRadius + CGFloat(i) * grooveSpacing
                let isOdd = i % 2 != 0

                // Base groove opacity
                var opacity = isOdd
                    ? VinylConstants.grooveAlternateOpacity
                    : VinylConstants.grooveBaseOpacity

                // Specular highlight: boost upper-left quadrant grooves
                let normalizedRadius = CGFloat(i) / CGFloat(grooveCount)
                if normalizedRadius > 0.2 && normalizedRadius < 0.8 {
                    opacity += VinylConstants.specularBoost * Double(1.0 - normalizedRadius)
                }

                let groovePath = Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .zero,
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                }

                context.stroke(
                    groovePath,
                    with: .color(.white.opacity(opacity)),
                    lineWidth: VinylConstants.grooveStrokeWidth
                )
            }

            // Specular highlight arc (upper-left)
            if !isMini {
                let highlightPath = Path { path in
                    path.addArc(
                        center: center,
                        radius: outerRadius * 0.65,
                        startAngle: .degrees(200),
                        endAngle: .degrees(310),
                        clockwise: false
                    )
                }
                context.stroke(
                    highlightPath,
                    with: .color(.white.opacity(0.04)),
                    lineWidth: outerRadius * 0.3
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }

    // MARK: - Layer 3: Album Art Label

    private var labelView: some View {
        ZStack {
            // Label background (fallback when no artwork)
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: labelDiameter, height: labelDiameter)

            // Album artwork clipped to circle
            if let artwork {
                ArtworkImage(artwork, width: labelDiameter)
                    .clipShape(Circle())
                    .frame(width: labelDiameter, height: labelDiameter)
            } else {
                // Placeholder: music note icon
                Image(systemName: "music.note")
                    .font(.system(size: labelDiameter * 0.35))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Label border ring
            Circle()
                .stroke(VinylConstants.labelBorder, lineWidth: isMini ? 0.5 : 1)
                .frame(width: labelDiameter, height: labelDiameter)
        }
    }

    // MARK: - Layer 4: Center Spindle

    private var spindleView: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        VinylConstants.spindleDark,
                        VinylConstants.spindleChrome
                    ],
                    center: UnitPoint(x: 0.4, y: 0.35),
                    startRadius: 0,
                    endRadius: spindleDiameter / 2
                )
            )
            .frame(width: spindleDiameter, height: spindleDiameter)
            .shadow(
                color: VinylConstants.spindleShadowColor,
                radius: VinylConstants.spindleShadowRadius,
                x: 0,
                y: 1
            )
    }

    // MARK: - Layer 5: Surface Reflection

    private var surfaceReflection: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(isMini ? 0.01 : 0.02),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .frame(width: diameter, height: diameter)
            .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview("Large Record") {
    ZStack {
        Color.black.ignoresSafeArea()
        VinylRecordView(artwork: nil, diameter: 300, rotationDegrees: 45)
    }
}

#Preview("Mini Record") {
    ZStack {
        Color.black.ignoresSafeArea()
        VinylRecordView(artwork: nil, diameter: 36, isMini: true)
    }
}
