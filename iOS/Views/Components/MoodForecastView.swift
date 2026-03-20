//
//  MoodForecastView.swift
//  Resonance
//
//  Interactive pre-session mood forecast visualization with draggable control points.
//  Users can adjust the predicted energy curve before a session starts, and the AI
//  will reorder the playlist to match the modified trajectory.
//

#if os(iOS)
import SwiftUI

// MARK: - Mood Forecast View

/// Displays an interactive energy curve with draggable control points.
/// Users drag points vertically to modify the energy target at that time segment.
/// The curve uses Catmull-Rom spline interpolation for smooth rendering.
struct MoodForecastView: View {
    @State var forecast: MoodForecast
    let onAccept: (MoodForecast) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Stores the original forecast for reset functionality.
    @State private var originalForecast: MoodForecast?

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            curveSection
            axisLabels
            actionButtons
        }
        .padding()
        .onAppear {
            if originalForecast == nil {
                originalForecast = forecast
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mood Forecast")
                    .font(.headline)

                Text(forecast.arcTemplate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            confidenceBadge

            Button("Reset") {
                resetForecast()
            }
            .font(.subheadline)
            .foregroundStyle(.orange)
        }
    }

    private var confidenceBadge: some View {
        Text("\(Int(forecast.confidence * 100))%")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(confidenceColor.opacity(0.2))
            )
            .foregroundStyle(confidenceColor)
    }

    private var confidenceColor: Color {
        switch forecast.confidence {
        case 0.8...: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    // MARK: - Interactive Curve

    private var curveSection: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                backgroundGrid(size: size)
                gradientFill(size: size)
                smoothCurve(size: size)
                controlPoints(size: size)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .coordinateSpace(name: "forecastChart")
    }

    // MARK: - Background Grid

    private func backgroundGrid(size: CGSize) -> some View {
        ZStack {
            // Horizontal grid lines (energy levels)
            ForEach(0..<11) { i in
                Path { path in
                    let y = size.height * (1.0 - CGFloat(i) / 10.0)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            }

            // Vertical grid lines (time segments)
            ForEach(0..<forecast.points.count, id: \.self) { i in
                Path { path in
                    let x = xPosition(for: forecast.points[i], in: size)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                .stroke(Color.gray.opacity(0.08), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Gradient Fill Under Curve

    private func gradientFill(size: CGSize) -> some View {
        Path { path in
            let cgPoints = forecast.points.map { pt in
                CGPoint(
                    x: xPosition(for: pt, in: size),
                    y: yPosition(for: pt, in: size)
                )
            }

            guard cgPoints.count >= 2 else { return }

            let curvePoints = catmullRomPoints(from: cgPoints, granularity: 20)

            path.move(to: CGPoint(x: curvePoints[0].x, y: size.height))
            path.addLine(to: curvePoints[0])

            for point in curvePoints.dropFirst() {
                path.addLine(to: point)
            }

            path.addLine(to: CGPoint(x: curvePoints.last!.x, y: size.height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Smooth Curve

    private func smoothCurve(size: CGSize) -> some View {
        Path { path in
            let cgPoints = forecast.points.map { pt in
                CGPoint(
                    x: xPosition(for: pt, in: size),
                    y: yPosition(for: pt, in: size)
                )
            }

            guard cgPoints.count >= 2 else { return }

            let curvePoints = catmullRomPoints(from: cgPoints, granularity: 20)

            path.move(to: curvePoints[0])
            for point in curvePoints.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Draggable Control Points

    private func controlPoints(size: CGSize) -> some View {
        ForEach(forecast.points.indices, id: \.self) { index in
            let point = forecast.points[index]
            let x = xPosition(for: point, in: size)
            let y = yPosition(for: point, in: size)

            ZStack {
                // BPM label above the point
                Text("\(Int(point.bpm))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .offset(y: -18)

                // Outer glow for modified points
                if point.isUserModified {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 28, height: 28)
                }

                // Control point circle
                Circle()
                    .fill(point.isUserModified ? Color.orange : Color.accentColor)
                    .frame(width: 16, height: 16)
                    .shadow(
                        color: (point.isUserModified ? Color.orange : Color.accentColor).opacity(0.4),
                        radius: 4
                    )
            }
            .position(x: x, y: y)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("forecastChart"))
                    .onChanged { value in
                        handleDrag(at: index, location: value.location, size: size)
                    }
            )
            .accessibilityLabel("Energy point \(index + 1)")
            .accessibilityValue("Energy \(Int(round(point.energy * 10))) of 10, \(Int(point.bpm)) BPM")
            .accessibilityAdjustableAction { direction in
                handleAccessibilityAdjust(at: index, direction: direction)
            }
        }
    }

    // MARK: - Axis Labels

    private var axisLabels: some View {
        VStack(spacing: 4) {
            // Energy scale
            HStack {
                Text("Low")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Energy")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("High")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            // Time labels
            HStack {
                Text("0:00")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(formatDuration(forecast.sessionDuration / 2))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(formatDuration(forecast.sessionDuration))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack {
            Button("Dismiss") {
                onDismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            Spacer()

            Button("Apply Forecast") {
                onAccept(forecast)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor)
            )
        }
    }

    // MARK: - Drag Handling

    /// Handles vertical drag on a control point, updating only energy (Y-axis).
    private func handleDrag(at index: Int, location: CGPoint, size: CGSize) {
        let newEnergy = Double(1.0 - location.y / size.height)
        let clampedEnergy = min(max(newEnergy, 0.0), 1.0)

        forecast.points[index].energy = clampedEnergy
        forecast.points[index].isUserModified = true

        // Recalculate BPM based on new energy
        let bpmRange = estimateBPMRange()
        forecast.points[index].bpm = bpmRange.min + clampedEnergy * (bpmRange.max - bpmRange.min)
    }

    /// Handles VoiceOver accessibility adjustments for control points.
    private func handleAccessibilityAdjust(
        at index: Int,
        direction: AccessibilityAdjustmentDirection
    ) {
        let step = 0.1
        switch direction {
        case .increment:
            forecast.points[index].energy = min(forecast.points[index].energy + step, 1.0)
        case .decrement:
            forecast.points[index].energy = max(forecast.points[index].energy - step, 0.0)
        @unknown default:
            break
        }
        forecast.points[index].isUserModified = true

        let bpmRange = estimateBPMRange()
        forecast.points[index].bpm = bpmRange.min
            + forecast.points[index].energy * (bpmRange.max - bpmRange.min)
    }

    // MARK: - Reset

    private func resetForecast() {
        if let original = originalForecast {
            forecast = original
        }
    }

    // MARK: - Coordinate Helpers

    private func xPosition(for point: ForecastPoint, in size: CGSize) -> CGFloat {
        let padding: CGFloat = 16
        let usableWidth = size.width - padding * 2
        let normalized = point.timestamp / forecast.sessionDuration
        return padding + usableWidth * CGFloat(normalized)
    }

    private func yPosition(for point: ForecastPoint, in size: CGSize) -> CGFloat {
        size.height * (1.0 - CGFloat(point.energy))
    }

    /// Estimates a BPM range from the current forecast template name.
    private func estimateBPMRange() -> (min: Double, max: Double) {
        switch forecast.arcTemplate {
        case "Workout":    return (100, 170)
        case "Relaxation": return (70, 100)
        case "Focus":      return (70, 110)
        case "Sleep":      return (60, 80)
        case "Morning":    return (70, 120)
        case "Commute":    return (90, 130)
        default:           return (70, 140)
        }
    }

    // MARK: - Catmull-Rom Spline

    /// Generates smooth curve points using Catmull-Rom spline interpolation.
    /// This produces a natural-looking curve through all control points.
    private func catmullRomPoints(
        from controlPoints: [CGPoint],
        granularity: Int
    ) -> [CGPoint] {
        guard controlPoints.count >= 2 else { return controlPoints }

        var result: [CGPoint] = []

        for i in 0..<controlPoints.count - 1 {
            let p0 = i > 0 ? controlPoints[i - 1] : controlPoints[i]
            let p1 = controlPoints[i]
            let p2 = controlPoints[i + 1]
            let p3 = i + 2 < controlPoints.count ? controlPoints[i + 2] : controlPoints[i + 1]

            for t in 0..<granularity {
                let tNorm = CGFloat(t) / CGFloat(granularity)
                let point = catmullRomInterpolate(p0: p0, p1: p1, p2: p2, p3: p3, t: tNorm)
                result.append(point)
            }
        }

        // Add the final point
        if let last = controlPoints.last {
            result.append(last)
        }

        return result
    }

    /// Evaluates a single point on a Catmull-Rom spline segment.
    private func catmullRomInterpolate(
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        let x = 0.5 * (
            (2.0 * p1.x) +
            (-p0.x + p2.x) * t +
            (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 +
            (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3
        )

        let y = 0.5 * (
            (2.0 * p1.y) +
            (-p0.y + p2.y) * t +
            (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 +
            (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3
        )

        return CGPoint(x: x, y: y)
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#Preview {
    MoodForecastView(
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
        onAccept: { _ in },
        onDismiss: { }
    )
    .padding()
}
#endif
