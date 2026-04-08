//
//  MoodTrajectoryOverlayView.swift
//  Resonance
//
//  Post-session overlay chart comparing the pre-session mood forecast
//  (dashed, lighter curve) against the actual biometric trajectory
//  (solid, accent-colored curve). Displayed in the session summary
//  at 150pt height.
//

#if os(iOS)

import SwiftUI

// MARK: - Mood Trajectory Overlay View

/// Overlays the predicted mood arc with the actual session trajectory.
/// Forecast is rendered as a dashed, semi-transparent line; actual
/// is rendered as a solid, accent-colored line. Both use Catmull-Rom
/// spline interpolation for smooth curves.
struct MoodTrajectoryOverlayView: View {
    let forecastPoints: [ForecastSnapshot]
    let actualSnapshots: [ActualStateSnapshot]

    /// Height of the chart area.
    private let chartHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(ResonanceColors.accent)
                    .font(.caption)

                Text("Mood Trajectory")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                legendView
            }

            // Chart with emotional Y-axis labels
            HStack(alignment: .top, spacing: 4) {
                // Emotional Y-axis labels
                GeometryReader { geo in
                    let height = geo.size.height
                    ForEach(EmotionalEnergyLabel.allCases, id: \.self) { label in
                        let y = height * (1.0 - CGFloat(label.midpoint))
                        Text(label.rawValue)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.quaternary)
                            .position(x: 24, y: y)
                    }
                }
                .frame(width: 48, height: chartHeight)

                // Chart area
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        backgroundGrid(size: size)

                        // Forecast curve (dashed, lighter)
                        if forecastPoints.count >= 2 {
                            forecastCurve(size: size)
                        }

                        // Actual curve (solid, accent)
                        if actualSnapshots.count >= 2 {
                            actualCurve(size: size)
                            actualGradientFill(size: size)
                        }
                    }
                }
                .frame(height: chartHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Time axis labels
            HStack {
                Text("Start")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("End")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 48) // Align with chart area
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground).opacity(0.5))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(ResonanceColors.accent.opacity(0.4))
                    .frame(width: 16, height: 2)
                    .overlay(
                        StrokeDashes()
                            .stroke(ResonanceColors.accent.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                            .frame(width: 16, height: 2)
                    )
                Text("Predicted")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(ResonanceColors.accent)
                    .frame(width: 16, height: 2)
                Text("Actual")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Background Grid

    private func backgroundGrid(size: CGSize) -> some View {
        ZStack {
            // Horizontal grid lines (energy levels)
            ForEach(0..<5, id: \.self) { i in
                Path { path in
                    let y = size.height * CGFloat(i) / 4.0
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.gray.opacity(0.12), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Forecast Curve (Dashed)

    private func forecastCurve(size: CGSize) -> some View {
        let cgPoints = forecastPoints.map { pt in
            CGPoint(
                x: size.width * CGFloat(pt.normalizedTime),
                y: size.height * (1.0 - CGFloat(pt.energy))
            )
        }
        let smooth = catmullRomPoints(from: cgPoints, granularity: 16)

        return Path { path in
            guard let first = smooth.first else { return }
            path.move(to: first)
            for point in smooth.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(
            ResonanceColors.accent.opacity(0.35),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
        )
    }

    // MARK: - Actual Curve (Solid)

    private func actualCurve(size: CGSize) -> some View {
        let cgPoints = actualSnapshots.map { pt in
            CGPoint(
                x: size.width * CGFloat(pt.normalizedTime),
                y: size.height * (1.0 - CGFloat(pt.energy))
            )
        }
        let smooth = catmullRomPoints(from: cgPoints, granularity: 16)

        return Path { path in
            guard let first = smooth.first else { return }
            path.move(to: first)
            for point in smooth.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(
            ResonanceColors.accent,
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Actual Gradient Fill

    private func actualGradientFill(size: CGSize) -> some View {
        let cgPoints = actualSnapshots.map { pt in
            CGPoint(
                x: size.width * CGFloat(pt.normalizedTime),
                y: size.height * (1.0 - CGFloat(pt.energy))
            )
        }
        let smooth = catmullRomPoints(from: cgPoints, granularity: 16)

        return Path { path in
            guard let first = smooth.first else { return }
            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            for point in smooth.dropFirst() {
                path.addLine(to: point)
            }
            if let last = smooth.last {
                path.addLine(to: CGPoint(x: last.x, y: size.height))
            }
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [ResonanceColors.accent.opacity(0.15), ResonanceColors.accent.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Catmull-Rom Spline (Delegate to Shared Utility)

    private func catmullRomPoints(
        from controlPoints: [CGPoint],
        granularity: Int
    ) -> [CGPoint] {
        CatmullRomSpline.interpolate(through: controlPoints, granularity: granularity)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var desc = "Mood trajectory chart. "
        if !forecastPoints.isEmpty {
            let avgForecast = forecastPoints.map(\.energy).reduce(0, +) / Double(forecastPoints.count)
            desc += "Predicted average energy \(Int(avgForecast * 100))%. "
        }
        if !actualSnapshots.isEmpty {
            let avgActual = actualSnapshots.map(\.energy).reduce(0, +) / Double(actualSnapshots.count)
            desc += "Actual average energy \(Int(avgActual * 100))%."
        }
        return desc
    }
}

// MARK: - Stroke Dashes Helper

/// A simple Shape that draws a horizontal line for the legend dash indicator.
private struct StrokeDashes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Preview

#Preview("Mood Trajectory Overlay") {
    let forecast: [ForecastSnapshot] = (0..<9).map { i in
        let t = Double(i) / 8.0
        return ForecastSnapshot(normalizedTime: t, energy: 0.3 + 0.4 * sin(t * .pi))
    }

    let actual: [ActualStateSnapshot] = (0..<12).map { i in
        let t = Double(i) / 11.0
        return ActualStateSnapshot(
            normalizedTime: t,
            energy: 0.25 + 0.45 * sin(t * .pi) + Double.random(in: -0.05...0.05),
            heartRate: 70 + 30 * sin(t * .pi)
        )
    }

    MoodTrajectoryOverlayView(
        forecastPoints: forecast,
        actualSnapshots: actual
    )
    .padding()
}

#endif
