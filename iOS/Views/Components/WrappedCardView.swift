//
//  WrappedCardView.swift
//  Resonance
//
//  Shareable "Resonance Wrapped" annual summary card in Instagram-story
//  aspect ratio (9:16). Renders key stats (total sessions, focus minutes,
//  top genre, best time-of-day, HRV improvement) on a gradient background
//  derived from session mood data.
//
//  Shared via ImageRenderer at 3x scale following the same pattern as
//  SessionShareCardView.swift. Brand watermark in bottom corner.
//
//  Privacy: Only aggregated, non-identifiable stats are shown.
//

#if os(iOS)

import SwiftUI

// MARK: - Wrapped Card Layout

private enum WrappedCardLayout {
    /// Instagram story aspect ratio (9:16).
    static let width: CGFloat = 390
    static let height: CGFloat = 693

    /// Render scale for ImageRenderer (3x for crisp output).
    static let renderScale: CGFloat = 3.0
}

// MARK: - Wrapped Stats Data

/// Aggregated data for the Resonance Wrapped card.
struct WrappedStatsData: Sendable {
    let totalSessions: Int
    let totalFocusMinutes: Int
    let mostResonantGenre: String
    let bestTimeOfDay: String
    let hrvImprovementPercent: Double
    /// Most resonant track title + artist (optional).
    let topTrackTitle: String?
    let topTrackArtist: String?
    /// Dominant mood for gradient derivation ("calm", "energize", "focus", "uplift").
    let dominantMood: String
    /// Year label (e.g. "2025").
    let year: String
}

// MARK: - Wrapped Card View

/// A beautiful annual summary card for sharing your music-health profile.
struct WrappedCardView: View {
    let stats: WrappedStatsData

    // MARK: - Gradient Colors

    private var gradientTop: Color {
        switch stats.dominantMood.lowercased() {
        case "calm":     return Color(red: 0.15, green: 0.25, blue: 0.50)
        case "energize": return Color(red: 0.55, green: 0.20, blue: 0.15)
        case "focus":    return Color(red: 0.10, green: 0.30, blue: 0.45)
        case "uplift":   return Color(red: 0.40, green: 0.20, blue: 0.55)
        default:         return Color(red: 0.12, green: 0.15, blue: 0.35)
        }
    }

    private var gradientMid: Color {
        switch stats.dominantMood.lowercased() {
        case "calm":     return Color(red: 0.10, green: 0.18, blue: 0.38)
        case "energize": return Color(red: 0.40, green: 0.12, blue: 0.18)
        case "focus":    return Color(red: 0.08, green: 0.20, blue: 0.35)
        case "uplift":   return Color(red: 0.28, green: 0.12, blue: 0.42)
        default:         return Color(red: 0.08, green: 0.10, blue: 0.25)
        }
    }

    private var gradientBottom: Color {
        Color(red: 0.04, green: 0.04, blue: 0.10)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [gradientTop, gradientMid, gradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative glow circles
            decorativeGlows

            VStack(spacing: 0) {
                Spacer(minLength: 48)

                // Year badge
                yearBadge
                    .padding(.bottom, 12)

                // Branding header
                brandingHeader
                    .padding(.bottom, 32)

                // Primary stat: Sessions
                primaryStat
                    .padding(.bottom, 28)

                // Stats grid
                statsGrid
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)

                // Insight sentence
                insightSentence
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                // Top track
                if let title = stats.topTrackTitle, let artist = stats.topTrackArtist {
                    topTrackSection(title: title, artist: artist)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 16)
                }

                Spacer(minLength: 20)

                // Footer watermark
                footerWatermark
                    .padding(.bottom, 36)
            }
        }
        .frame(width: WrappedCardLayout.width, height: WrappedCardLayout.height)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Year Badge

    private var yearBadge: some View {
        Text(stats.year)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.white.opacity(0.1))
            )
    }

    // MARK: - Branding Header

    private var brandingHeader: some View {
        VStack(spacing: 6) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.9))

            Text("Resonance")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Wrapped")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(4)
                .textCase(.uppercase)
        }
    }

    // MARK: - Primary Stat

    private var primaryStat: some View {
        VStack(spacing: 4) {
            Text("\(stats.totalSessions)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text("listening sessions")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 0) {
            wrappedStatItem(
                value: formatMinutes(stats.totalFocusMinutes),
                label: "Focus Time"
            )

            Divider()
                .frame(height: 36)
                .background(.white.opacity(0.15))

            wrappedStatItem(
                value: stats.mostResonantGenre,
                label: "Top Genre"
            )

            Divider()
                .frame(height: 36)
                .background(.white.opacity(0.15))

            wrappedStatItem(
                value: stats.bestTimeOfDay.capitalized,
                label: "Best Time"
            )
        }
    }

    private func wrappedStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insight Sentence

    private var insightSentence: some View {
        VStack(spacing: 8) {
            if stats.hrvImprovementPercent > 0 {
                Text("Your HRV improved by \(String(format: "%.0f", stats.hrvImprovementPercent))%")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            Text("Your heart's favorite genre at \(stats.bestTimeOfDay.lowercased())")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .italic()
        }
    }

    // MARK: - Top Track Section

    private func topTrackSection(title: String, artist: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow.opacity(0.8))
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(artist)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Decorative Glows

    private var decorativeGlows: some View {
        ZStack {
            Circle()
                .fill(gradientTop.opacity(0.3))
                .frame(width: 200, height: 200)
                .blur(radius: 80)
                .offset(x: -100, y: -180)

            Circle()
                .fill(ResonanceColors.accent.opacity(0.15))
                .frame(width: 160, height: 160)
                .blur(radius: 60)
                .offset(x: 120, y: 100)
        }
    }

    // MARK: - Footer Watermark

    private var footerWatermark: some View {
        Text("resonance")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.2))
            .tracking(2)
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }

    private var accessibilityDescription: String {
        var parts = [
            "Resonance Wrapped \(stats.year)",
            "\(stats.totalSessions) sessions",
            "\(formatMinutes(stats.totalFocusMinutes)) focus time",
            "Top genre: \(stats.mostResonantGenre)",
            "Best time: \(stats.bestTimeOfDay)"
        ]
        if stats.hrvImprovementPercent > 0 {
            parts.append("HRV improved by \(String(format: "%.0f", stats.hrvImprovementPercent)) percent")
        }
        if let track = stats.topTrackTitle, let artist = stats.topTrackArtist {
            parts.append("Top track: \(track) by \(artist)")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Wrapped Card Renderer

/// Renders a `WrappedCardView` to a `UIImage` for sharing via ShareLink.
/// Uses `ImageRenderer` at 3x scale following the SessionShareCardView pattern.
@MainActor
enum WrappedCardRenderer {

    /// Renders the wrapped card to a `SwiftUI.Image` suitable for ShareLink.
    static func render(stats: WrappedStatsData) -> Image {
        let cardView = WrappedCardView(stats: stats)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = WrappedCardLayout.renderScale
        renderer.proposedSize = ProposedViewSize(
            width: WrappedCardLayout.width,
            height: WrappedCardLayout.height
        )

        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }

        // Fallback: placeholder image
        return Image(systemName: "photo")
    }

    /// Renders the wrapped card to a `UIImage` for programmatic sharing.
    static func renderUIImage(stats: WrappedStatsData) -> UIImage? {
        let cardView = WrappedCardView(stats: stats)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = WrappedCardLayout.renderScale
        renderer.proposedSize = ProposedViewSize(
            width: WrappedCardLayout.width,
            height: WrappedCardLayout.height
        )

        return renderer.uiImage
    }
}

// MARK: - Preview

#Preview("Wrapped Card - Calm") {
    ScrollView {
        WrappedCardView(
            stats: WrappedStatsData(
                totalSessions: 247,
                totalFocusMinutes: 3420,
                mostResonantGenre: "Ambient",
                bestTimeOfDay: "evening",
                hrvImprovementPercent: 18,
                topTrackTitle: "Weightless",
                topTrackArtist: "Marconi Union",
                dominantMood: "calm",
                year: "2025"
            )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .padding()
    }
    .background(Color.black)
}

#Preview("Wrapped Card - Energize") {
    ScrollView {
        WrappedCardView(
            stats: WrappedStatsData(
                totalSessions: 184,
                totalFocusMinutes: 2100,
                mostResonantGenre: "Electronic",
                bestTimeOfDay: "morning",
                hrvImprovementPercent: 12,
                topTrackTitle: "Midnight City",
                topTrackArtist: "M83",
                dominantMood: "energize",
                year: "2025"
            )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .padding()
    }
    .background(Color.black)
}

#Preview("Wrapped Card - No Top Track") {
    ScrollView {
        WrappedCardView(
            stats: WrappedStatsData(
                totalSessions: 52,
                totalFocusMinutes: 780,
                mostResonantGenre: "Classical",
                bestTimeOfDay: "afternoon",
                hrvImprovementPercent: 8,
                topTrackTitle: nil,
                topTrackArtist: nil,
                dominantMood: "focus",
                year: "2025"
            )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .padding()
    }
    .background(Color.black)
}

#endif
