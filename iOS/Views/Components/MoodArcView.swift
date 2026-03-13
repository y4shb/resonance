//
//  MoodArcView.swift
//  Resonance
//
//  Visualizes the planned song energy arc — showing where Resonance intends
//  to take the user's biometric state over the next several songs.
//  Each dot represents a queued song's target energy level.
//

import SwiftUI

// MARK: - Mood Arc Data Point

/// A single point in the mood arc visualization.
struct MoodArcPoint: Identifiable, Equatable {
    let id = UUID()
    let songTitle: String
    let targetEnergy: Double  // 0.0 - 1.0
    let isPlaying: Bool
    let isCompleted: Bool

    static func == (lhs: MoodArcPoint, rhs: MoodArcPoint) -> Bool {
        lhs.songTitle == rhs.songTitle
            && lhs.targetEnergy == rhs.targetEnergy
            && lhs.isPlaying == rhs.isPlaying
            && lhs.isCompleted == rhs.isCompleted
    }
}

// MARK: - Mood Arc View

/// Horizontal dot chart showing the energy trajectory of upcoming songs.
struct MoodArcView: View {
    let points: [MoodArcPoint]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundStyle(.blue)
                    .font(.caption2)

                Text("Session Arc")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(points.count) songs")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Arc visualization
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let pointCount = max(points.count, 1)
                let spacing = width / CGFloat(pointCount + 1)

                ZStack {
                    // Connecting line
                    Path { path in
                        for (index, point) in points.enumerated() {
                            let x = spacing * CGFloat(index + 1)
                            let y = height * (1.0 - CGFloat(point.targetEnergy))

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                    // Data points
                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        let x = spacing * CGFloat(index + 1)
                        let y = height * (1.0 - CGFloat(point.targetEnergy))

                        Circle()
                            .fill(pointColor(for: point, index: index))
                            .frame(width: dotSize(for: point, index: index),
                                   height: dotSize(for: point, index: index))
                            .shadow(
                                color: point.isPlaying ? .blue.opacity(0.5) : .clear,
                                radius: point.isPlaying ? 4 : 0
                            )
                            .scaleEffect(point.isPlaying && !reduceMotion ? 1.2 : 1.0)
                            .animation(
                                reduceMotion ? .none : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: point.isPlaying
                            )
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 40)

            // Energy labels
            HStack {
                Text("Low")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("High")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session mood arc: \(points.count) songs planned")
    }

    // MARK: - Helpers

    private func pointColor(for point: MoodArcPoint, index: Int) -> Color {
        if point.isPlaying {
            return .blue
        } else if point.isCompleted {
            return .green.opacity(0.6)
        } else {
            return .purple.opacity(0.5)
        }
    }

    private func dotSize(for point: MoodArcPoint, index: Int) -> CGFloat {
        point.isPlaying ? 10 : 7
    }
}

// MARK: - Preview

#Preview {
    MoodArcView(
        points: [
            MoodArcPoint(songTitle: "Song 1", targetEnergy: 0.3, isPlaying: false, isCompleted: true),
            MoodArcPoint(songTitle: "Song 2", targetEnergy: 0.4, isPlaying: false, isCompleted: true),
            MoodArcPoint(songTitle: "Song 3", targetEnergy: 0.5, isPlaying: true, isCompleted: false),
            MoodArcPoint(songTitle: "Song 4", targetEnergy: 0.65, isPlaying: false, isCompleted: false),
            MoodArcPoint(songTitle: "Song 5", targetEnergy: 0.7, isPlaying: false, isCompleted: false),
            MoodArcPoint(songTitle: "Song 6", targetEnergy: 0.6, isPlaying: false, isCompleted: false),
        ]
    )
    .padding()
}
