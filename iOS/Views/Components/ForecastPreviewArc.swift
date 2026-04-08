//
//  ForecastPreviewArc.swift
//  Resonance
//
//  A compact, non-interactive preview of a MoodForecast energy curve.
//  Shown inline within SessionIntentPicker below the selected intent card
//  to give the user a visual preview before committing to the full editor.
//

#if os(iOS)
import SwiftUI

// MARK: - Forecast Preview Arc

/// A compact, non-interactive rendering of a MoodForecast energy arc.
///
/// Height: ~100pt. Shows the Catmull-Rom spline, gradient fill, and small
/// track-type hint icons along the curve. No draggable control points.
/// Tapping the preview opens the full interactive MoodForecastView.
struct ForecastPreviewArc: View {
    let forecast: MoodForecast
    let intentColor: Color
    var onTap: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 6) {
                // Mini curve
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        previewGradientFill(size: size)
                        previewCurve(size: size)
                        trackTypeIcons(size: size)
                    }
                }
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Compact info row
                HStack(spacing: 12) {
                    Label(
                        forecast.arcTemplate,
                        systemImage: "waveform.path"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(forecast.confidence * 100))% confidence")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Forecast preview: \(forecast.arcTemplate)")
        .accessibilityHint("Tap to customize the energy curve")
    }

    // MARK: - Preview Gradient Fill

    private func previewGradientFill(size: CGSize) -> some View {
        Path { path in
            let cgPoints = forecast.points.map { pt in
                CGPoint(
                    x: xPosition(for: pt, in: size),
                    y: yPosition(for: pt, in: size)
                )
            }

            guard cgPoints.count >= 2 else { return }

            let curvePoints = catmullRomPoints(from: cgPoints, granularity: 16)

            path.move(to: CGPoint(x: curvePoints[0].x, y: size.height))
            path.addLine(to: curvePoints[0])

            for point in curvePoints.dropFirst() {
                path.addLine(to: point)
            }

            if let lastPoint = curvePoints.last {
                path.addLine(to: CGPoint(x: lastPoint.x, y: size.height))
            }
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [intentColor.opacity(0.2), intentColor.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Preview Curve Line

    private func previewCurve(size: CGSize) -> some View {
        Path { path in
            let cgPoints = forecast.points.map { pt in
                CGPoint(
                    x: xPosition(for: pt, in: size),
                    y: yPosition(for: pt, in: size)
                )
            }

            guard cgPoints.count >= 2 else { return }

            let curvePoints = catmullRomPoints(from: cgPoints, granularity: 16)

            path.move(to: curvePoints[0])
            for point in curvePoints.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(
            LinearGradient(
                colors: [intentColor, intentColor.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Track Type Icons Along Curve

    private func trackTypeIcons(size: CGSize) -> some View {
        ForEach(forecast.points.indices, id: \.self) { index in
            let point = forecast.points[index]
            let x = xPosition(for: point, in: size)
            let y = yPosition(for: point, in: size)
            let hint = TrackTypeHint.from(energy: point.energy)

            Image(systemName: hint.sfSymbol)
                .font(.system(size: 7))
                .foregroundStyle(hint.color.opacity(0.7))
                .position(x: x, y: max(y - 12, 8))
        }
    }

    // MARK: - Coordinate Helpers

    private func xPosition(for point: ForecastPoint, in size: CGSize) -> CGFloat {
        let padding: CGFloat = 8
        let usableWidth = size.width - padding * 2
        let normalized = point.timestamp / forecast.sessionDuration
        return padding + usableWidth * CGFloat(normalized)
    }

    private func yPosition(for point: ForecastPoint, in size: CGSize) -> CGFloat {
        let verticalPadding: CGFloat = 8
        let usableHeight = size.height - verticalPadding * 2
        return verticalPadding + usableHeight * (1.0 - CGFloat(point.energy))
    }

    // MARK: - Catmull-Rom Spline (Delegate to Shared Utility)

    private func catmullRomPoints(
        from controlPoints: [CGPoint],
        granularity: Int
    ) -> [CGPoint] {
        CatmullRomSpline.interpolate(through: controlPoints, granularity: granularity)
    }
}

// MARK: - Track Type Hint

/// Maps energy levels to predicted track characteristics with SF Symbols.
enum TrackTypeHint {
    case ambient      // Very low energy (0.0-0.2)
    case acoustic     // Low energy (0.2-0.4)
    case electronic   // Medium-high energy (0.4-0.7)
    case rock         // High energy (0.7-0.85)
    case intense      // Very high energy (0.85-1.0)

    /// Determines the track type hint based on energy level.
    static func from(energy: Double) -> TrackTypeHint {
        switch energy {
        case ..<0.2:       return .ambient
        case 0.2..<0.4:    return .acoustic
        case 0.4..<0.7:    return .electronic
        case 0.7..<0.85:   return .rock
        default:           return .intense
        }
    }

    /// SF Symbol representing the predicted track characteristic.
    var sfSymbol: String {
        switch self {
        case .ambient:    return "moon.haze.fill"
        case .acoustic:   return "guitars.fill"
        case .electronic: return "bolt.fill"
        case .rock:       return "speaker.wave.3.fill"
        case .intense:    return "flame.fill"
        }
    }

    /// Color tint for the track type icon.
    var color: Color {
        switch self {
        case .ambient:    return .indigo
        case .acoustic:   return .teal
        case .electronic: return .cyan
        case .rock:       return .orange
        case .intense:    return .red
        }
    }

    /// Human-readable label for accessibility.
    var label: String {
        switch self {
        case .ambient:    return "Ambient"
        case .acoustic:   return "Acoustic"
        case .electronic: return "Electronic"
        case .rock:       return "Energetic"
        case .intense:    return "Intense"
        }
    }
}

// MARK: - Emotional Energy Label

/// Maps energy levels to emotional words for the Y-axis.
enum EmotionalEnergyLabel: String, CaseIterable {
    case grounded  = "Grounded"    // 0.0-0.2
    case settling  = "Settling"    // 0.2-0.4
    case flowing   = "Flowing"     // 0.4-0.6
    case lifted    = "Lifted"      // 0.6-0.8
    case energized = "Energized"   // 0.8-1.0

    /// Returns the emotional label for a given energy value.
    static func from(energy: Double) -> EmotionalEnergyLabel {
        switch energy {
        case ..<0.2:       return .grounded
        case 0.2..<0.4:    return .settling
        case 0.4..<0.6:    return .flowing
        case 0.6..<0.8:    return .lifted
        default:           return .energized
        }
    }

    /// The energy band midpoint for positioning on the Y-axis.
    var midpoint: Double {
        switch self {
        case .grounded:  return 0.1
        case .settling:  return 0.3
        case .flowing:   return 0.5
        case .lifted:    return 0.7
        case .energized: return 0.9
        }
    }
}

// MARK: - Preview

#Preview("Forecast Preview Arc") {
    ForecastPreviewArc(
        forecast: MoodForecast(
            points: [
                ForecastPoint(id: 0, energy: 0.3, bpm: 80, timestamp: 0),
                ForecastPoint(id: 1, energy: 0.4, bpm: 90, timestamp: 225),
                ForecastPoint(id: 2, energy: 0.55, bpm: 105, timestamp: 450),
                ForecastPoint(id: 3, energy: 0.7, bpm: 120, timestamp: 675),
                ForecastPoint(id: 4, energy: 0.8, bpm: 135, timestamp: 900),
                ForecastPoint(id: 5, energy: 0.75, bpm: 128, timestamp: 1125),
                ForecastPoint(id: 6, energy: 0.6, bpm: 110, timestamp: 1350),
                ForecastPoint(id: 7, energy: 0.45, bpm: 95, timestamp: 1575),
                ForecastPoint(id: 8, energy: 0.3, bpm: 80, timestamp: 1800),
            ],
            arcTemplate: "Workout",
            sessionDuration: 1800,
            confidence: 0.75
        ),
        intentColor: .red
    )
    .padding()
}
#endif
