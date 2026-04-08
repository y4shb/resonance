//
//  ResonanceScoreView.swift
//  Resonance
//
//  Post-session resonance score display with concentric ring graph
//  (Apple Fitness-style) and per-track breakdown.
//
//  Three rings:
//    Outer: overall score (primary blue)
//    Middle: biometric alignment (green)
//    Inner: engagement (purple)
//

import SwiftUI

// MARK: - Resonance Score View

struct ResonanceScoreView: View {
    let result: ResonanceScoreResult

    /// Controls ring fill animation on appear.
    @State private var animateRings = false

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            ringGraphSection
            gradeLabel
            Divider()
            perTrackBreakdown
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animateRings = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(ResonanceColors.accent)

            Text("Resonance Score")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()
        }
    }

    // MARK: - Ring Graph

    private var ringGraphSection: some View {
        ZStack {
            // Outer ring: Overall Score
            ringView(
                progress: animateRings ? Double(result.overallScore) / 100.0 : 0,
                lineWidth: 18,
                color: ResonanceColors.accent,
                size: 160
            )

            // Middle ring: Biometric Alignment
            ringView(
                progress: animateRings ? Double(result.biometricScore) / 100.0 : 0,
                lineWidth: 14,
                color: .green,
                size: 118
            )

            // Inner ring: Engagement
            ringView(
                progress: animateRings ? Double(result.engagementScore) / 100.0 : 0,
                lineWidth: 10,
                color: .purple,
                size: 82
            )

            // Center score number
            VStack(spacing: 2) {
                Text("\(result.overallScore)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("/ 100")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Resonance score \(result.overallScore) out of 100")
    }

    private func ringView(
        progress: Double,
        lineWidth: CGFloat,
        color: Color,
        size: CGFloat
    ) -> some View {
        ZStack {
            // Background track
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Filled arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.7), value: progress)
        }
    }

    // MARK: - Grade Label

    private var gradeLabel: some View {
        VStack(spacing: 6) {
            Text(result.grade.label)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(result.grade.color)

            // Ring legend
            HStack(spacing: 16) {
                legendItem(color: ResonanceColors.accent, label: "Overall")
                legendItem(color: .green, label: "Biometric")
                legendItem(color: .purple, label: "Engagement")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            // Session stats
            HStack(spacing: 12) {
                Label(
                    "\(result.tracksPlayed) tracks",
                    systemImage: "music.note"
                )
                Label(
                    formattedDuration,
                    systemImage: "clock"
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    // MARK: - Per-Track Breakdown

    private var perTrackBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track Breakdown")
                .font(.subheadline)
                .fontWeight(.medium)

            if result.perTrackData.isEmpty {
                Text("No track data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(result.perTrackData.enumerated()), id: \.offset) { _, track in
                    trackRow(track)
                }
            }
        }
    }

    private func trackRow(_ track: TrackResonanceData) -> some View {
        HStack(spacing: 10) {
            // Alignment indicator
            Circle()
                .fill(alignmentColor(track.alignment))
                .frame(width: 10, height: 10)

            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.songTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(track.artistName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Alignment percentage
            Text("\(Int(track.alignment * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(alignmentColor(track.alignment))

            // Skip indicator
            if track.wasSkipped {
                Image(systemName: "forward.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(track.songTitle) by \(track.artistName), "
            + "\(Int(track.alignment * 100))% alignment"
            + (track.wasSkipped ? ", skipped" : "")
        )
    }

    // MARK: - Helpers

    private func alignmentColor(_ alignment: Double) -> Color {
        if alignment > 0.7 { return .green }
        if alignment > 0.4 { return .orange }
        return .red
    }

    private var formattedDuration: String {
        let minutes = Int(result.sessionDuration / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - Preview

#Preview {
    let sampleTracks: [TrackResonanceData] = [
        TrackResonanceData(
            songTitle: "Midnight City",
            artistName: "M83",
            songAppleMusicId: "abc123",
            alignment: 0.92,
            hrDirectionMatch: true,
            completionRatio: 1.0,
            wasSkipped: false
        ),
        TrackResonanceData(
            songTitle: "Intro",
            artistName: "The xx",
            songAppleMusicId: "def456",
            alignment: 0.78,
            hrDirectionMatch: true,
            completionRatio: 0.95,
            wasSkipped: false
        ),
        TrackResonanceData(
            songTitle: "Blinding Lights",
            artistName: "The Weeknd",
            songAppleMusicId: "ghi789",
            alignment: 0.35,
            hrDirectionMatch: false,
            completionRatio: 0.3,
            wasSkipped: true
        ),
    ]

    let result = ResonanceScoreResult(
        overallScore: 78,
        biometricScore: 82,
        engagementScore: 72,
        perTrackData: sampleTracks,
        sessionDuration: 1800,
        tracksPlayed: 3,
        bestTrack: sampleTracks.first
    )

    ScrollView {
        ResonanceScoreView(result: result)
            .padding()
    }
}
