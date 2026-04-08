//
//  SessionSummaryView.swift
//  Resonance
//
//  Post-session summary card shown after a listening session ends (>15 minutes).
//  Displays session stats, HRV trend, best-fit song, and optional feedback.
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

    /// Convenience initializer preserving backward compatibility for callers
    /// that do not yet provide a resonance score or bookmarks.
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
        bookmarks: [SonicBookmarkData] = []
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
    }
}

// MARK: - Session Summary View

struct SessionSummaryView: View {
    let summary: SessionSummaryData
    var onDismiss: () -> Void
    var onFeedback: ((SessionFeedback) -> Void)?

    @State private var selectedFeedback: SessionFeedback?
    @State private var showingFeedback = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundStyle(ResonanceColors.accent)

                Text("Session Complete")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .accessibilityLabel("Dismiss summary")
            }

            // Resonance Score (shown when available)
            if let resonanceScore = summary.resonanceScore {
                ResonanceScoreView(result: resonanceScore)
            }

            // Stats grid
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

            // HRV Trend
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

            // Best fit song
            if let bestSong = summary.bestFitSong {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best Match")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("\(bestSong.title) — \(bestSong.artist)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }

            // Bookmarked Moments
            if !summary.bookmarks.isEmpty {
                BookmarkTimelineView(
                    bookmarks: summary.bookmarks,
                    sessionDuration: summary.sessionDuration
                )
            }

            // Session quality bar
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

            Divider()

            // Feedback section
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session summary: \(summary.songsPlayed) songs played over \(formattedDuration)")
    }

    // MARK: - Feedback Buttons

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
        case .great: return "\u{1F60D}"  // Heart eyes
        case .okay: return "\u{1F610}"   // Neutral
        case .rough: return "\u{1F615}"  // Confused/rough
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

// MARK: - Preview

#Preview {
    SessionSummaryView(
        summary: SessionSummaryData(
            sessionDuration: 2400,
            songsPlayed: 12,
            songsSkipped: 2,
            skipRate: 0.167,
            hrvImproved: true,
            hrvDelta: 3.5,
            bestFitSong: (title: "Weightless", artist: "Marconi Union"),
            averageBPM: 95,
            sessionQualityScore: 0.82
        ),
        onDismiss: {}
    )
    .padding()
}
