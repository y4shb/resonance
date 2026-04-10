//
//  AnxietyInterventionReportView.swift
//  Resonance
//
//  Post-episode report showing the biometric timeline during an anxiety episode,
//  including HR + HRV line charts, track list with per-track biometric impact,
//  and a before/after HRV comparison summary.
//
//  Uses Swift Charts for timeline visualization and follows the project's glass
//  card design language with ResonanceColors.accent for positive indicators.
//

import SwiftUI
import Charts

// MARK: - Report Data Types

/// A single data point for the biometric timeline chart.
struct AnxietyTimelinePoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let series: AnxietyTimelineSeries
}

/// Series type for the anxiety timeline chart.
enum AnxietyTimelineSeries: String, CaseIterable {
    case heartRate = "Heart Rate"
    case hrv = "HRV"

    var color: Color {
        switch self {
        case .heartRate: return .red
        case .hrv: return .green
        }
    }

    var icon: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .hrv: return "waveform.path.ecg"
        }
    }
}

// MARK: - Anxiety Intervention Report View

/// Displays a post-episode report summarizing an anxiety episode and the
/// music intervention's biometric impact. Designed as a glass card.
struct AnxietyInterventionReportView: View {
    let episode: AnxietyEpisode
    let timelineSnapshots: [AnxietyBiometricSnapshot]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateIn = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                biometricChartSection
                trackListSection
                regulationSummarySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if reduceMotion {
                animateIn = true
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    animateIn = true
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Anxiety intervention report")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(ResonanceColors.accent)
                    .font(.subheadline)
                    .accessibilityHidden(true)

                Text("Intervention Report")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                episodeStatPill(
                    label: "Peak",
                    value: String(format: "%.0f%%", episode.peakScore * 100),
                    color: peakColor
                )

                episodeStatPill(
                    label: "Tracks",
                    value: "\(episode.tracksDuringEpisode.count)",
                    color: ResonanceColors.accent
                )

                if let delta = episode.hrvBeforeAfter.delta {
                    episodeStatPill(
                        label: "HRV",
                        value: String(format: "%+.0fms", delta),
                        color: delta > 0 ? .green : .orange
                    )
                }
            }
        }
        .padding()
        .glassEffect(.regular)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    // MARK: - Biometric Chart

    private var biometricChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(ResonanceColors.accent)
                    .font(.caption)
                    .accessibilityHidden(true)

                Text("Biometric Timeline")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()
            }

            if chartDataPoints.isEmpty {
                Text("No biometric data recorded during this episode.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart {
                    ForEach(chartDataPoints) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Value", point.value),
                            series: .value("Series", point.series.rawValue)
                        )
                        .foregroundStyle(by: .value("Series", point.series.rawValue))
                        .lineStyle(StrokeStyle(
                            lineWidth: point.series == .hrv ? 1.5 : 2
                        ))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartForegroundStyleScale([
                    AnxietyTimelineSeries.heartRate.rawValue: AnxietyTimelineSeries.heartRate.color,
                    AnxietyTimelineSeries.hrv.rawValue: AnxietyTimelineSeries.hrv.color,
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.minute().second())
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 160)

                // Legend
                HStack(spacing: 12) {
                    ForEach(AnxietyTimelineSeries.allCases, id: \.self) { series in
                        HStack(spacing: 4) {
                            Image(systemName: series.icon)
                                .font(.caption2)
                                .foregroundStyle(series.color)
                            Text(series.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(series.rawValue)
                    }
                }
            }
        }
        .padding()
        .glassEffect(.regular)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Biometric timeline chart showing heart rate and HRV during episode")
    }

    // MARK: - Track List

    private var trackListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundStyle(ResonanceColors.accent)
                    .font(.caption)
                    .accessibilityHidden(true)

                Text("Tracks During Episode")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()
            }

            if episode.tracksDuringEpisode.isEmpty {
                Text("No tracks were recorded during this episode.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(episode.tracksDuringEpisode) { track in
                    trackRow(track)
                }
            }
        }
        .padding()
        .glassEffect(.regular)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tracks played during anxiety episode")
    }

    /// A single track row showing title, artist, and biometric impact.
    private func trackRow(_ track: EpisodeTrack) -> some View {
        HStack(spacing: 10) {
            // Impact indicator
            Circle()
                .fill(track.anxietyScoreChange < 0 ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let hr = track.hrDuringTrack {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                        Text("\(Int(hr))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Heart rate \(Int(hr)) BPM")
                }

                if let hrv = track.hrvDuringTrack {
                    HStack(spacing: 2) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                        Text("\(Int(hrv))ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("HRV \(Int(hrv)) milliseconds")
                }
            }

            // Score change badge
            Text(String(format: "%+.0f%%", track.anxietyScoreChange * 100))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(track.anxietyScoreChange < 0 ? .green : .orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill((track.anxietyScoreChange < 0 ? Color.green : Color.orange).opacity(0.15))
                )
                .accessibilityLabel(
                    track.anxietyScoreChange < 0
                        ? "Anxiety reduced by \(Int(abs(track.anxietyScoreChange) * 100)) percent"
                        : "Anxiety increased by \(Int(track.anxietyScoreChange * 100)) percent"
                )
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Regulation Summary

    private var regulationSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: regulationIcon)
                    .foregroundStyle(regulationColor)
                    .font(.caption)
                    .accessibilityHidden(true)

                Text(regulationTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(regulationColor)

                Spacer()
            }

            // Before / After comparison
            if let before = episode.hrvBeforeAfter.hrvBefore,
               let after = episode.hrvBeforeAfter.hrvAfter {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("Before")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(before))ms")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("HRV before episode: \(Int(before)) milliseconds")

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    VStack(spacing: 4) {
                        Text("After")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(after))ms")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(after > before ? .green : .orange)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("HRV after episode: \(Int(after)) milliseconds")

                    Spacer()

                    if let delta = episode.hrvBeforeAfter.delta {
                        VStack(spacing: 4) {
                            Text("Change")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%+.0fms", delta))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(delta > 0 ? .green : .orange)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            delta > 0
                                ? "HRV improved by \(Int(delta)) milliseconds"
                                : "HRV decreased by \(Int(abs(delta))) milliseconds"
                        )
                    }
                }
            }

            Text(regulationDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("This is not a medical assessment. Consult a healthcare professional for anxiety concerns.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding()
        .glassEffect(.regular)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(regulationAccessibilityLabel)
    }

    // MARK: - Helpers

    private var chartDataPoints: [AnxietyTimelinePoint] {
        var points: [AnxietyTimelinePoint] = []
        for snapshot in timelineSnapshots {
            if let hr = snapshot.heartRate {
                points.append(AnxietyTimelinePoint(
                    timestamp: snapshot.timestamp,
                    value: hr,
                    series: .heartRate
                ))
            }
            if let hrv = snapshot.hrv {
                points.append(AnxietyTimelinePoint(
                    timestamp: snapshot.timestamp,
                    value: hrv,
                    series: .hrv
                ))
            }
        }
        return points
    }

    private func episodeStatPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var formattedDuration: String {
        let seconds = Int(episode.duration)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        }
        return "\(remainingSeconds)s"
    }

    private var peakColor: Color {
        if episode.peakScore >= AnxietyConstants.acuteThreshold { return .red }
        if episode.peakScore >= AnxietyConstants.anxiousThreshold { return .orange }
        return .yellow
    }

    // MARK: - Regulation Summary Helpers

    private var regulationIcon: String {
        episode.hrvBeforeAfter.improved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var regulationColor: Color {
        episode.hrvBeforeAfter.improved ? .green : .orange
    }

    private var regulationTitle: String {
        episode.hrvBeforeAfter.improved
            ? "Music Helped Regulate"
            : "Episode Recorded"
    }

    private var regulationDescription: String {
        if episode.hrvBeforeAfter.improved, let delta = episode.hrvBeforeAfter.delta {
            return "Your HRV improved by \(Int(delta))ms during this episode, "
                + "indicating the music intervention helped your autonomic nervous system "
                + "return toward a calmer state."
        }
        return "This episode has been recorded. The AI DJ will learn from this "
            + "pattern to improve future anxiety interventions."
    }

    // MARK: - Accessibility Labels

    private var headerAccessibilityLabel: String {
        var parts = ["Anxiety intervention report"]
        parts.append("Duration: \(formattedDuration)")
        parts.append("Peak anxiety: \(Int(episode.peakScore * 100)) percent")
        parts.append("\(episode.tracksDuringEpisode.count) tracks played")
        if let delta = episode.hrvBeforeAfter.delta {
            parts.append(delta > 0
                ? "HRV improved by \(Int(delta)) milliseconds"
                : "HRV decreased by \(Int(abs(delta))) milliseconds")
        }
        return parts.joined(separator: ". ")
    }

    private var regulationAccessibilityLabel: String {
        if episode.hrvBeforeAfter.improved {
            return "Music helped regulate your anxiety. \(regulationDescription)"
        }
        return "Episode recorded. \(regulationDescription)"
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    let episode = AnxietyEpisode(
        startTime: now.addingTimeInterval(-600),
        endTime: now,
        peakScore: 0.72,
        triggerSignals: ["HR elevated", "HRV dropping"],
        tracksDuringEpisode: [
            EpisodeTrack(
                title: "Weightless",
                artist: "Marconi Union",
                startedAt: now.addingTimeInterval(-540),
                hrDuringTrack: 88,
                hrvDuringTrack: 32,
                anxietyScoreChange: -0.15
            ),
            EpisodeTrack(
                title: "Electra",
                artist: "Airstream",
                startedAt: now.addingTimeInterval(-300),
                hrDuringTrack: 82,
                hrvDuringTrack: 38,
                anxietyScoreChange: -0.12
            ),
            EpisodeTrack(
                title: "Mellomaniac (Chill Out Mix)",
                artist: "DJ Shah",
                startedAt: now.addingTimeInterval(-120),
                hrDuringTrack: 76,
                hrvDuringTrack: 44,
                anxietyScoreChange: -0.08
            ),
        ],
        hrvBeforeAfter: HRVComparison(hrvBefore: 28, hrvAfter: 44)
    )

    let snapshots: [AnxietyBiometricSnapshot] = stride(from: -600, through: 0, by: 60).map { offset in
        let progress = Double(offset + 600) / 600.0
        return AnxietyBiometricSnapshot(
            timestamp: now.addingTimeInterval(TimeInterval(offset)),
            heartRate: 95 - progress * 19,
            hrv: 28 + progress * 16,
            anxietyScore: 0.72 - progress * 0.42
        )
    }

    return AnxietyInterventionReportView(
        episode: episode,
        timelineSnapshots: snapshots
    )
}
