//
//  SessionSummaryComponents.swift
//  Resonance
//
//  Supporting models and subviews for the post-session summary.
//  Contains: data models (ForecastSnapshot, ActualStateSnapshot,
//  HighlightTrack, PerTrackBiometricDetail, SessionTrendInsight),
//  and enhancement subviews (HighlightMomentView, SessionTrendInsightRow,
//  PerTrackBreakdownSection, InlineHRSparkline).
//

import SwiftUI

// MARK: - Forecast Snapshot

/// A single point from the pre-session mood forecast, used for the
/// post-session overlay comparison.
struct ForecastSnapshot: Sendable {
    /// Normalized time offset within the session (0.0 = start, 1.0 = end).
    let normalizedTime: Double
    /// Predicted energy level (0.0 - 1.0).
    let energy: Double
}

// MARK: - Actual State Snapshot

/// A timestamped state observation captured during the session,
/// used to compare actual mood trajectory against the forecast.
struct ActualStateSnapshot: Sendable {
    /// Normalized time offset within the session (0.0 = start, 1.0 = end).
    let normalizedTime: Double
    /// Observed energy level derived from biometrics (0.0 - 1.0).
    let energy: Double
    /// Heart rate at this moment, if available.
    let heartRate: Double?
}

// MARK: - Highlight Track

/// The track where biometrics showed peak engagement during the session.
struct HighlightTrack: Sendable {
    let title: String
    let artist: String
    let appleMusicId: String
    /// Per-track alignment score (0.0 - 1.0); highest in the session.
    let alignmentScore: Double
    /// Heart rate observed at peak engagement.
    let heartRate: Double?
    /// Album artwork data for display and share card gradient.
    let artworkData: Data?
}

// MARK: - Per-Track Biometric Detail

/// Extended per-track data including inline heart rate samples for the
/// enhanced per-track breakdown view.
struct PerTrackBiometricDetail: Identifiable, Sendable {
    let id = UUID()
    let songTitle: String
    let artistName: String
    let alignment: Double
    let wasSkipped: Bool
    /// Heart rate samples normalized to [0, 1] time range within the track.
    let heartRateSamples: [(normalizedTime: Double, bpm: Double)]
}

// MARK: - Session Trend Insight

/// Historical session trend data for the "This is your Nth session" insight.
struct SessionTrendInsight: Sendable {
    /// Total sessions of this type (e.g., "evening sessions").
    let sessionCount: Int
    /// Label for the session category (e.g., "evening", "workout").
    let sessionTypeLabel: String
    /// Percentage improvement or decline in the primary metric.
    /// Positive = improvement, negative = decline.
    let trendDelta: Double
    /// The metric being tracked (e.g., "wind-down time", "energy gain").
    let trendMetricLabel: String
}

// MARK: - Highlight Moment View

/// Prominently displays the track with peak biometric engagement,
/// distinguished by a gold accent border.
struct HighlightMomentView: View {
    let track: HighlightTrack
    var onBookmark: () -> Void

    /// Gold accent color used consistently throughout the highlight card.
    private let goldAccent = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section label
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundStyle(goldAccent)
                    .font(.caption)
                Text("Highlight Moment")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(goldAccent)
            }

            HStack(spacing: 12) {
                // Album art placeholder or image
                Group {
                    if let data = track.artworkData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(goldAccent.opacity(0.6), lineWidth: 2)
                )

                // Song info
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(Int(track.alignmentScore * 100))% alignment")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)

                        if let hr = track.heartRate {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.red)
                                Text("\(Int(hr)) bpm")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                Button(action: onBookmark) {
                    Image(systemName: "bookmark")
                        .font(.body)
                        .foregroundStyle(goldAccent)
                }
                .accessibilityLabel("Bookmark highlight track")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(goldAccent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(goldAccent.opacity(0.25), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Highlight moment: \(track.title) by \(track.artist), "
            + "\(Int(track.alignmentScore * 100))% alignment"
        )
    }
}

// MARK: - Session Trend Insight Row

/// Displays a historical session trend insight with a directional icon.
struct SessionTrendInsightRow: View {
    let insight: SessionTrendInsight

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: insight.trendDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(insight.trendDelta >= 0 ? .green : .orange)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill((insight.trendDelta >= 0 ? Color.green : Color.orange).opacity(0.12))
                )

            Text(trendText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(trendText)
    }

    private var trendText: String {
        let ordinal = ordinalSuffix(for: insight.sessionCount)
        let direction = insight.trendDelta >= 0 ? "improved" : "declined"
        let pct = Int(abs(insight.trendDelta * 100))
        return "This is your \(insight.sessionCount)\(ordinal) \(insight.sessionTypeLabel) session. "
            + "Your \(insight.trendMetricLabel) \(direction) \(pct)%."
    }

    private func ordinalSuffix(for n: Int) -> String {
        let ones = n % 10
        let tens = (n / 10) % 10
        if tens == 1 { return "th" }
        switch ones {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}

// MARK: - Per-Track Biometric Breakdown Section

/// Expandable per-track breakdown with inline heart rate charts.
struct PerTrackBreakdownSection: View {
    let tracks: [PerTrackBiometricDetail]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(ResonanceColors.accent)
                        .font(.caption)

                    Text("Track Biometrics")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Track biometric breakdown, \(isExpanded ? "collapse" : "expand")")

            if isExpanded {
                ForEach(tracks) { track in
                    PerTrackBiometricRow(track: track)
                }
            }
        }
    }
}

/// A single row in the per-track biometric breakdown showing an inline
/// heart rate spark line alongside song info and alignment percentage.
struct PerTrackBiometricRow: View {
    let track: PerTrackBiometricDetail

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(alignmentColor)
                .frame(width: 10, height: 10)

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
            .frame(maxWidth: 120, alignment: .leading)

            if !track.heartRateSamples.isEmpty {
                InlineHRSparkline(samples: track.heartRateSamples)
                    .frame(height: 24)
            }

            Spacer(minLength: 4)

            Text("\(Int(track.alignment * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(alignmentColor)

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

    private var alignmentColor: Color {
        if track.alignment > 0.7 { return .green }
        if track.alignment > 0.4 { return .orange }
        return .red
    }
}

/// A tiny inline spark line chart showing heart rate trend during a track.
struct InlineHRSparkline: View {
    let samples: [(normalizedTime: Double, bpm: Double)]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let minBPM = samples.map(\.bpm).min() ?? 60
            let maxBPM = samples.map(\.bpm).max() ?? 100
            let range = max(maxBPM - minBPM, 1)

            Path { path in
                for (i, sample) in samples.enumerated() {
                    let x = size.width * CGFloat(sample.normalizedTime)
                    let y = size.height * (1.0 - CGFloat((sample.bpm - minBPM) / range))
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [.red.opacity(0.6), .red.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
