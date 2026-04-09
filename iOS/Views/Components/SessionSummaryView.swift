//
//  SessionSummaryView.swift
//  Resonance
//
//  Post-session summary card shown after a listening session ends (>15 minutes).
//  Displays session stats, HRV trend, best-fit song, mood trajectory overlay,
//  highlight moment, session trend insight, shareable card, and optional feedback.
//
//  Supporting models and subviews live in SessionSummaryComponents.swift.
//

import SwiftUI

// MARK: - Session Summary Data

/// Data model for a completed listening session summary.
struct SessionSummaryData {
    let sessionDuration: TimeInterval
    let songsPlayed: Int
    let songsSkipped: Int
    let skipRate: Double
    let hrvImproved: Bool
    let hrvDelta: Double  // Positive = improved
    let bestFitSong: (title: String, artist: String)?
    let averageBPM: Double
    let sessionQualityScore: Double  // 0.0 - 1.0
    /// Post-session resonance score (biometric-music correlation). Nil if not computed.
    let resonanceScore: ResonanceScoreResult?

    /// Sonic Bookmarks captured during this session.
    var bookmarks: [SonicBookmarkData]

    // MARK: - Enhancement 1: Forecast vs. Actual Trajectory

    /// Pre-session forecast points for the trajectory overlay.
    var forecastPoints: [ForecastSnapshot]

    /// Actual biometric state snapshots captured during the session.
    var actualStateSnapshots: [ActualStateSnapshot]

    // MARK: - Enhancement 2: Highlight Moment

    /// The track with peak biometric engagement, if identified.
    var highlightTrack: HighlightTrack?

    // MARK: - Enhancement 3: Session Trend Insight

    /// Historical trend insight (e.g., "12th evening session, 15% improvement").
    var trendInsight: SessionTrendInsight?

    // MARK: - Enhancement 5: Per-Track Biometric Breakdown

    /// Extended per-track data with inline HR samples.
    var perTrackDetails: [PerTrackBiometricDetail]

    /// Convenience initializer preserving backward compatibility for callers
    /// that do not yet provide enhancement data.
    init(
        sessionDuration: TimeInterval,
        songsPlayed: Int,
        songsSkipped: Int,
        skipRate: Double,
        hrvImproved: Bool,
        hrvDelta: Double,
        bestFitSong: (title: String, artist: String)?,
        averageBPM: Double,
        sessionQualityScore: Double,
        resonanceScore: ResonanceScoreResult? = nil,
        bookmarks: [SonicBookmarkData] = [],
        forecastPoints: [ForecastSnapshot] = [],
        actualStateSnapshots: [ActualStateSnapshot] = [],
        highlightTrack: HighlightTrack? = nil,
        trendInsight: SessionTrendInsight? = nil,
        perTrackDetails: [PerTrackBiometricDetail] = []
    ) {
        self.sessionDuration = sessionDuration
        self.songsPlayed = songsPlayed
        self.songsSkipped = songsSkipped
        self.skipRate = skipRate
        self.hrvImproved = hrvImproved
        self.hrvDelta = hrvDelta
        self.bestFitSong = bestFitSong
        self.averageBPM = averageBPM
        self.sessionQualityScore = sessionQualityScore
        self.resonanceScore = resonanceScore
        self.bookmarks = bookmarks
        self.forecastPoints = forecastPoints
        self.actualStateSnapshots = actualStateSnapshots
        self.highlightTrack = highlightTrack
        self.trendInsight = trendInsight
        self.perTrackDetails = perTrackDetails
    }
}

// MARK: - Session Summary View

struct SessionSummaryView: View {
    let summary: SessionSummaryData
    var onDismiss: () -> Void
    var onFeedback: ((SessionFeedback) -> Void)?
    var onBookmarkHighlight: ((HighlightTrack) -> Void)?

    @State private var selectedFeedback: SessionFeedback?
    @State private var showingFeedback = false
    @State private var showingPerTrackBreakdown = false
    @State private var cachedShareImage: Image?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                resonanceScoreSection
                trajectoryOverlaySection
                statsGrid
                trendInsightSection
                hrvTrend
                highlightMomentSection
                bestFitSongFallback
                bookmarksSection
                perTrackBreakdownSection
                qualityBar
                Divider()
                feedbackSection
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session summary: \(summary.songsPlayed) songs played over \(formattedDuration)")
        .task {
            // Pre-render share card image once to avoid expensive duplicate ImageRenderer calls
            if summary.resonanceScore != nil {
                cachedShareImage = SessionShareCardRenderer.render(summary: summary)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "music.note.list")
                .foregroundStyle(ResonanceColors.accent)

            Text("Session Complete")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            // Share button (Enhancement 4) — image pre-rendered to avoid duplicate renders
            if summary.resonanceScore != nil, let shareImage = cachedShareImage {
                ShareLink(
                    item: shareImage,
                    preview: SharePreview("Resonance Session", image: shareImage)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(ResonanceColors.accent)
                        .font(.subheadline)
                }
                .accessibilityLabel("Share session card")
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .accessibilityLabel("Dismiss summary")
        }
    }

    // MARK: - Resonance Score

    @ViewBuilder
    private var resonanceScoreSection: some View {
        if let resonanceScore = summary.resonanceScore {
            ResonanceScoreView(result: resonanceScore)
        }
    }

    // MARK: - Enhancement 1: Trajectory Overlay

    @ViewBuilder
    private var trajectoryOverlaySection: some View {
        if !summary.forecastPoints.isEmpty || !summary.actualStateSnapshots.isEmpty {
            MoodTrajectoryOverlayView(
                forecastPoints: summary.forecastPoints,
                actualSnapshots: summary.actualStateSnapshots
            )
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            ResonanceMetricCell(
                icon: "clock.fill",
                value: formattedDuration,
                label: "Duration",
                color: ResonanceColors.accent
            )

            ResonanceMetricCell(
                icon: "music.note",
                value: "\(summary.songsPlayed)",
                label: "Songs",
                color: .purple
            )

            ResonanceMetricCell(
                icon: "forward.fill",
                value: "\(Int(summary.skipRate * 100))%",
                label: "Skip Rate",
                color: summary.skipRate < 0.2 ? .green : .orange
            )
        }
    }

    // MARK: - Enhancement 3: Session Trend Insight

    @ViewBuilder
    private var trendInsightSection: some View {
        if let trend = summary.trendInsight {
            SessionTrendInsightRow(insight: trend)
        }
    }

    // MARK: - HRV Trend

    private var hrvTrend: some View {
        HStack(spacing: 8) {
            Image(systemName: summary.hrvImproved ? "arrow.up.heart.fill" : "arrow.down.heart.fill")
                .foregroundStyle(summary.hrvImproved ? .green : .orange)

            Text(summary.hrvImproved
                 ? "HRV improved during this session (+\(String(format: "%.1f", abs(summary.hrvDelta)))ms)"
                 : "HRV decreased slightly (\(String(format: "%.1f", abs(summary.hrvDelta)))ms)")
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Enhancement 2: Highlight Moment

    @ViewBuilder
    private var highlightMomentSection: some View {
        if let highlight = summary.highlightTrack {
            HighlightMomentView(
                track: highlight,
                onBookmark: { onBookmarkHighlight?(highlight) }
            )
        }
    }

    // MARK: - Best Fit Song Fallback

    @ViewBuilder
    private var bestFitSongFallback: some View {
        if summary.highlightTrack == nil, let bestSong = summary.bestFitSong {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Best Match")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(bestSong.title) -- \(bestSong.artist)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }

    // MARK: - Bookmarks

    @ViewBuilder
    private var bookmarksSection: some View {
        if !summary.bookmarks.isEmpty {
            BookmarkTimelineView(
                bookmarks: summary.bookmarks,
                sessionDuration: summary.sessionDuration
            )
        }
    }

    // MARK: - Enhancement 5: Per-Track Biometric Breakdown

    @ViewBuilder
    private var perTrackBreakdownSection: some View {
        if !summary.perTrackDetails.isEmpty {
            PerTrackBreakdownSection(
                tracks: summary.perTrackDetails,
                isExpanded: $showingPerTrackBreakdown
            )
        }
    }

    // MARK: - Quality Bar

    private var qualityBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Session Quality")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(qualityLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(qualityColor)
            }

            ResonanceProgressBar(
                progress: summary.sessionQualityScore,
                color: qualityColor,
                height: 6
            )
        }
    }

    // MARK: - Feedback

    @ViewBuilder
    private var feedbackSection: some View {
        if !showingFeedback {
            Button(action: { showingFeedback = true }) {
                Text("How was this session?")
                    .font(.subheadline)
                    .foregroundStyle(ResonanceColors.accent)
            }
        } else {
            feedbackButtons
        }
    }

    private var feedbackButtons: some View {
        HStack(spacing: 12) {
            ForEach(SessionFeedback.allCases, id: \.self) { feedback in
                Button(action: {
                    selectedFeedback = feedback
                    onFeedback?(feedback)
                }) {
                    VStack(spacing: 4) {
                        Text(feedback.emoji)
                            .font(.title2)
                        Text(feedback.label)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedFeedback == feedback
                                  ? feedback.color.opacity(0.2)
                                  : Color(.tertiarySystemFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(selectedFeedback == feedback ? feedback.color : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(feedback.label) session")
            }
        }
    }

    // MARK: - Computed Properties

    private var formattedDuration: String {
        let minutes = Int(summary.sessionDuration / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private var qualityLabel: String {
        if summary.sessionQualityScore > 0.8 { return "Excellent" }
        if summary.sessionQualityScore > 0.6 { return "Good" }
        if summary.sessionQualityScore > 0.4 { return "Fair" }
        return "Could improve"
    }

    private var qualityColor: Color {
        if summary.sessionQualityScore > 0.8 { return .green }
        if summary.sessionQualityScore > 0.6 { return ResonanceColors.accent }
        if summary.sessionQualityScore > 0.4 { return .orange }
        return .red
    }
}

// MARK: - Supporting Types

struct StatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

enum SessionFeedback: String, CaseIterable {
    case great = "great"
    case okay = "okay"
    case rough = "rough"

    var emoji: String {
        switch self {
        case .great: return "\u{1F60D}"
        case .okay: return "\u{1F610}"
        case .rough: return "\u{1F615}"
        }
    }

    var label: String {
        switch self {
        case .great: return "Great"
        case .okay: return "Okay"
        case .rough: return "Rough"
        }
    }

    var color: Color {
        switch self {
        case .great: return .green
        case .okay: return .orange
        case .rough: return .red
        }
    }
}

// MARK: - Previews

#Preview("Session Summary - Full") {
    let sampleForecast: [ForecastSnapshot] = (0..<9).map { i in
        let t = Double(i) / 8.0
        return ForecastSnapshot(normalizedTime: t, energy: 0.3 + 0.4 * sin(t * .pi))
    }

    let sampleActual: [ActualStateSnapshot] = (0..<12).map { i in
        let t = Double(i) / 11.0
        return ActualStateSnapshot(
            normalizedTime: t,
            energy: 0.25 + 0.45 * sin(t * .pi) + Double.random(in: -0.05...0.05),
            heartRate: 70 + 30 * sin(t * .pi)
        )
    }

    let hrSamples1: [(Double, Double)] = (0..<8).map { i in
        (Double(i) / 7.0, 72.0 + Double(i) * 3.0)
    }
    let hrSamples2: [(Double, Double)] = (0..<8).map { i in
        (Double(i) / 7.0, 80.0 - Double(i) * 1.5)
    }
    let hrSamples3: [(Double, Double)] = (0..<5).map { i in
        (Double(i) / 4.0, 90.0 + Double(i) * 2.0)
    }
    let samplePerTrack: [PerTrackBiometricDetail] = [
        PerTrackBiometricDetail(
            songTitle: "Midnight City", artistName: "M83",
            alignment: 0.92, wasSkipped: false,
            heartRateSamples: hrSamples1
        ),
        PerTrackBiometricDetail(
            songTitle: "Intro", artistName: "The xx",
            alignment: 0.78, wasSkipped: false,
            heartRateSamples: hrSamples2
        ),
        PerTrackBiometricDetail(
            songTitle: "Blinding Lights", artistName: "The Weeknd",
            alignment: 0.35, wasSkipped: true,
            heartRateSamples: hrSamples3
        ),
    ]

    let sampleHighlight = HighlightTrack(
        title: "Midnight City", artist: "M83", appleMusicId: "abc123",
        alignmentScore: 0.92, heartRate: 96, artworkData: nil
    )
    let sampleTrend = SessionTrendInsight(
        sessionCount: 12, sessionTypeLabel: "evening",
        trendDelta: 0.15, trendMetricLabel: "wind-down time"
    )
    let sampleSummary = SessionSummaryData(
        sessionDuration: 2400, songsPlayed: 12, songsSkipped: 2,
        skipRate: 0.167, hrvImproved: true, hrvDelta: 3.5,
        bestFitSong: (title: "Weightless", artist: "Marconi Union"),
        averageBPM: 95, sessionQualityScore: 0.82,
        forecastPoints: sampleForecast,
        actualStateSnapshots: sampleActual,
        highlightTrack: sampleHighlight,
        trendInsight: sampleTrend,
        perTrackDetails: samplePerTrack
    )

    ScrollView {
        SessionSummaryView(summary: sampleSummary, onDismiss: {})
            .padding()
    }
}

#Preview("Session Summary - Minimal") {
    SessionSummaryView(
        summary: SessionSummaryData(
            sessionDuration: 2400, songsPlayed: 12, songsSkipped: 2,
            skipRate: 0.167, hrvImproved: true, hrvDelta: 3.5,
            bestFitSong: (title: "Weightless", artist: "Marconi Union"),
            averageBPM: 95, sessionQualityScore: 0.82
        ),
        onDismiss: {}
    )
    .padding()
}
