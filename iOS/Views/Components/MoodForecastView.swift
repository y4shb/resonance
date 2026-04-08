//
//  MoodForecastView.swift
//  Resonance
//
//  Interactive pre-session mood forecast visualization with draggable control points.
//  Users can adjust the predicted energy curve before a session starts, and the AI
//  will reorder the playlist to match the modified trajectory.
//
//  Also supports a post-session overlay mode showing predicted vs actual curves.
//

#if os(iOS)
import SwiftUI

// MARK: - Mood Forecast View

/// Displays an interactive energy curve with draggable control points.
/// Users drag points vertically to modify the energy target at that time segment.
/// The curve uses Catmull-Rom spline interpolation for smooth rendering.
///
/// In overlay mode (`actualTrajectory` provided), shows two curves:
/// - Predicted arc: dashed, lighter opacity
/// - Actual trajectory: solid, brighter color
struct MoodForecastView: View {
    @State var forecast: MoodForecast
    let onAccept: (MoodForecast) -> Void
    let onDismiss: () -> Void

    /// Optional actual trajectory for post-session overlay comparison.
    /// When provided, the view switches to read-only overlay mode.
    var actualTrajectory: [ForecastPoint]?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Stores the original forecast for reset functionality.
    @State private var originalForecast: MoodForecast?

    /// Whether we are in post-session overlay mode (read-only).
    private var isOverlayMode: Bool {
        actualTrajectory != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            emotionalYAxisWithCurve
            timeAxisLabels
            if !isOverlayMode {
                actionButtons
            } else {
                overlayLegend
            }
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
                Text(isOverlayMode ? "Session Trajectory" : "Mood Forecast")
                    .font(.headline)

                Text(forecast.arcTemplate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isOverlayMode {
                confidenceBadge

                Button("Reset") {
                    resetForecast()
                }
                .font(.subheadline)
                .foregroundStyle(.orange)
            }
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

    // MARK: - Emotional Y-Axis + Curve (Combined Layout)

    /// Combines the emotional word labels on the left with the curve chart.
    private var emotionalYAxisWithCurve: some View {
        HStack(alignment: .top, spacing: 4) {
            // Emotional Y-axis labels
            GeometryReader { geo in
                let height = geo.size.height
                ForEach(EmotionalEnergyLabel.allCases, id: \.self) { label in
                    let y = height * (1.0 - CGFloat(label.midpoint))
                    Text(label.rawValue)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .position(x: 28, y: y)
                }
            }
            .frame(width: 56, height: 200)

            // Main curve area
            curveSection
        }
    }

    // MARK: - Interactive Curve

    private var curveSection: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                backgroundGrid(size: size)

                if isOverlayMode {
                    // Overlay mode: predicted (dashed) + actual (solid)
                    predictedGradientFill(size: size)
                    predictedDashedCurve(size: size)
                    if let actual = actualTrajectory {
                        actualCurveFill(points: actual, size: size)
                        actualCurve(points: actual, size: size)
                    }
                } else {
                    // Interactive mode: single curve with control points
                    gradientFill(size: size)
                    smoothCurve(size: size)
                    trackTypeIcons(size: size)
                    controlPoints(size: size)
                }
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .coordinateSpace(name: "forecastChart")
    }

    // MARK: - Background Grid

    private func backgroundGrid(size: CGSize) -> some View {
        ZStack {
            // Horizontal grid lines -- aligned to emotional energy bands
            ForEach(0..<6) { i in
                let energy = CGFloat(i) * 0.2
                Path { path in
                    let y = size.height * (1.0 - energy)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.gray.opacity(0.12), lineWidth: 0.5)
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

            if let lastPoint = curvePoints.last {
                path.addLine(to: CGPoint(x: lastPoint.x, y: size.height))
            }
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
                colors: [ResonanceColors.accent, .purple],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Track Type Icons Along Curve

    /// Small SF Symbol icons along the curve indicating predicted track characteristics.
    private func trackTypeIcons(size: CGSize) -> some View {
        ForEach(forecast.points.indices, id: \.self) { index in
            let point = forecast.points[index]
            let x = xPosition(for: point, in: size)
            let y = yPosition(for: point, in: size)
            let hint = TrackTypeHint.from(energy: point.energy)

            Image(systemName: hint.sfSymbol)
                .font(.system(size: 8))
                .foregroundStyle(hint.color.opacity(0.65))
                .position(x: x, y: max(y - 22, 10))
        }
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
            .accessibilityValue(
                "\(EmotionalEnergyLabel.from(energy: point.energy).rawValue), "
                + "\(Int(point.bpm)) BPM, "
                + "\(TrackTypeHint.from(energy: point.energy).label)"
            )
            .accessibilityAdjustableAction { direction in
                handleAccessibilityAdjust(at: index, direction: direction)
            }
        }
    }

    // MARK: - Overlay Mode: Predicted Curve (Dashed)

    private func predictedGradientFill(size: CGSize) -> some View {
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
            if let lastPoint = curvePoints.last {
                path.addLine(to: CGPoint(x: lastPoint.x, y: size.height))
            }
            path.closeSubpath()
        }
        .fill(Color.gray.opacity(0.06))
    }

    private func predictedDashedCurve(size: CGSize) -> some View {
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
            Color.gray.opacity(0.5),
            style: StrokeStyle(
                lineWidth: 2,
                lineCap: .round,
                lineJoin: .round,
                dash: [6, 4]
            )
        )
    }

    // MARK: - Overlay Mode: Actual Trajectory (Solid)

    private func actualCurveFill(points: [ForecastPoint], size: CGSize) -> some View {
        Path { path in
            let cgPoints = points.map { pt in
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
            if let lastPoint = curvePoints.last {
                path.addLine(to: CGPoint(x: lastPoint.x, y: size.height))
            }
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [ResonanceColors.accent.opacity(0.25), ResonanceColors.accent.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func actualCurve(points: [ForecastPoint], size: CGSize) -> some View {
        Path { path in
            let cgPoints = points.map { pt in
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
                colors: [ResonanceColors.accent, .green],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Overlay Legend

    private var overlayLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 20, height: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            .frame(width: 20, height: 2)
                    )
                Text("Predicted")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(ResonanceColors.accent)
                    .frame(width: 20, height: 2)
                Text("Actual")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Time Axis Labels

    private var timeAxisLabels: some View {
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
        .padding(.leading, 56) // Align with curve area (past emotional labels)
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

    // MARK: - Catmull-Rom Spline (Delegate to Shared Utility)

    private func catmullRomPoints(
        from controlPoints: [CGPoint],
        granularity: Int
    ) -> [CGPoint] {
        CatmullRomSpline.interpolate(through: controlPoints, granularity: granularity)
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Previews

#Preview("Interactive Mode") {
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

#Preview("Overlay Mode") {
    MoodForecastView(
        forecast: MoodForecast(
            points: [
                ForecastPoint(id: 0, energy: 0.3, bpm: 80, timestamp: 0),
                ForecastPoint(id: 1, energy: 0.45, bpm: 95, timestamp: 300),
                ForecastPoint(id: 2, energy: 0.6, bpm: 110, timestamp: 600),
                ForecastPoint(id: 3, energy: 0.75, bpm: 128, timestamp: 900),
                ForecastPoint(id: 4, energy: 0.8, bpm: 135, timestamp: 1200),
                ForecastPoint(id: 5, energy: 0.65, bpm: 115, timestamp: 1500),
                ForecastPoint(id: 6, energy: 0.4, bpm: 90, timestamp: 1800),
            ],
            arcTemplate: "Workout",
            sessionDuration: 1800,
            confidence: 0.75
        ),
        onAccept: { _ in },
        onDismiss: { },
        actualTrajectory: [
            ForecastPoint(id: 0, energy: 0.35, bpm: 85, timestamp: 0),
            ForecastPoint(id: 1, energy: 0.5, bpm: 100, timestamp: 300),
            ForecastPoint(id: 2, energy: 0.7, bpm: 120, timestamp: 600),
            ForecastPoint(id: 3, energy: 0.85, bpm: 140, timestamp: 900),
            ForecastPoint(id: 4, energy: 0.75, bpm: 128, timestamp: 1200),
            ForecastPoint(id: 5, energy: 0.55, bpm: 105, timestamp: 1500),
            ForecastPoint(id: 6, energy: 0.35, bpm: 85, timestamp: 1800),
        ]
    )
    .padding()
}
#endif
