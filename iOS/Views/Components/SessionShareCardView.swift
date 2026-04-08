//
//  SessionShareCardView.swift
//  Resonance
//
//  Instagram-story-sized (9:16) shareable card rendered from session data.
//  Shows mood arc, resonance score, duration, and best track on an
//  album-art-derived gradient background. Rendered via ImageRenderer
//  and shared via ShareLink.
//
//  Privacy: The share card intentionally omits raw biometric data
//  (heart rate, HRV) and only shows aggregated scores and metadata.
//

#if os(iOS)

import SwiftUI

// MARK: - Share Card Dimensions

private enum ShareCardLayout {
    /// Instagram story aspect ratio (9:16).
    static let width: CGFloat = 1080 / 3   // 360pt at 3x
    static let height: CGFloat = 1920 / 3  // 640pt at 3x

    /// Render scale for ImageRenderer (3x for crisp output).
    static let renderScale: CGFloat = 3.0
}

// MARK: - Session Share Card View

/// A beautiful gradient card summarizing the session for social sharing.
/// Displays: mood arc, resonance score, duration, best track, and branding.
/// Uses album-art-derived colors for the gradient background; falls back
/// to the Resonance accent palette when no artwork is available.
struct SessionShareCardView: View {
    let summary: SessionSummaryData

    /// Dominant color extracted from album artwork (optional).
    var artworkDominantColor: Color?

    // MARK: - Gradient Colors

    private var gradientTop: Color {
        artworkDominantColor ?? Color(red: 0.12, green: 0.15, blue: 0.35)
    }

    private var gradientBottom: Color {
        Color(red: 0.05, green: 0.05, blue: 0.12)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [gradientTop, gradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // App branding
                brandingHeader
                    .padding(.bottom, 24)

                // Resonance Score ring
                scoreRing
                    .padding(.bottom, 20)

                // Mood arc mini chart
                if !summary.actualStateSnapshots.isEmpty || !summary.forecastPoints.isEmpty {
                    miniMoodArc
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }

                // Stats row
                statsRow
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                // Best track
                bestTrackRow
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                Spacer(minLength: 24)

                // Footer
                footerBranding
                    .padding(.bottom, 32)
            }
        }
        .frame(width: ShareCardLayout.width, height: ShareCardLayout.height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Branding Header

    private var brandingHeader: some View {
        VStack(spacing: 4) {
            Image(systemName: "waveform.path.ecg")
                .font(.title)
                .foregroundStyle(.white.opacity(0.9))

            Text("Resonance")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Session Summary")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(.white.opacity(0.1), lineWidth: 12)
                .frame(width: 120, height: 120)

            // Filled arc
            if let score = summary.resonanceScore {
                Circle()
                    .trim(from: 0, to: Double(score.overallScore) / 100.0)
                    .stroke(
                        .white,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
            }

            // Center text
            VStack(spacing: 2) {
                if let score = summary.resonanceScore {
                    Text("\(score.overallScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                } else {
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text("Resonance")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Mini Mood Arc

    private var miniMoodArc: some View {
        GeometryReader { geo in
            let size = geo.size
            let points = summary.actualStateSnapshots.isEmpty
                ? summary.forecastPoints.map { ($0.normalizedTime, $0.energy) }
                : summary.actualStateSnapshots.map { ($0.normalizedTime, $0.energy) }

            ZStack {
                // Gradient fill under curve
                Path { path in
                    guard points.count >= 2 else { return }
                    let first = points[0]
                    path.move(to: CGPoint(x: size.width * CGFloat(first.0), y: size.height))
                    path.addLine(to: CGPoint(
                        x: size.width * CGFloat(first.0),
                        y: size.height * (1.0 - CGFloat(first.1))
                    ))
                    for pt in points.dropFirst() {
                        path.addLine(to: CGPoint(
                            x: size.width * CGFloat(pt.0),
                            y: size.height * (1.0 - CGFloat(pt.1))
                        ))
                    }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: size.width * CGFloat(last.0), y: size.height))
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    guard points.count >= 2 else { return }
                    let first = points[0]
                    path.move(to: CGPoint(
                        x: size.width * CGFloat(first.0),
                        y: size.height * (1.0 - CGFloat(first.1))
                    ))
                    for pt in points.dropFirst() {
                        path.addLine(to: CGPoint(
                            x: size.width * CGFloat(pt.0),
                            y: size.height * (1.0 - CGFloat(pt.1))
                        ))
                    }
                }
                .stroke(
                    .white.opacity(0.7),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(height: 60)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            shareStatItem(
                value: formattedDuration,
                label: "Duration"
            )

            Divider()
                .frame(height: 28)
                .background(.white.opacity(0.2))

            shareStatItem(
                value: "\(summary.songsPlayed)",
                label: "Tracks"
            )

            Divider()
                .frame(height: 28)
                .background(.white.opacity(0.2))

            shareStatItem(
                value: "\(Int(summary.averageBPM))",
                label: "Avg BPM"
            )
        }
    }

    private func shareStatItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Best Track

    private var bestTrackRow: some View {
        Group {
            if let highlight = summary.highlightTrack {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow.opacity(0.8))
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(highlight.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(highlight.artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.08))
                )
            } else if let best = summary.bestFitSong {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow.opacity(0.8))
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(best.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(best.artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.08))
                )
            }
        }
    }

    // MARK: - Footer

    private var footerBranding: some View {
        Text("resonance.app")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.3))
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        let minutes = Int(summary.sessionDuration / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - Session Share Card Renderer

/// Renders a `SessionShareCardView` to a transferable `Image` for ShareLink.
/// Uses `ImageRenderer` at 3x scale for crisp social media output.
@MainActor
enum SessionShareCardRenderer {

    /// Renders the share card to a `SwiftUI.Image` suitable for ShareLink.
    static func render(summary: SessionSummaryData) -> Image {
        let cardView = SessionShareCardView(summary: summary)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = ShareCardLayout.renderScale
        renderer.proposedSize = ProposedViewSize(
            width: ShareCardLayout.width,
            height: ShareCardLayout.height
        )

        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }

        // Fallback: empty image
        return Image(systemName: "photo")
    }

    /// Renders the share card to a `UIImage` for programmatic sharing.
    static func renderUIImage(summary: SessionSummaryData) -> UIImage? {
        let cardView = SessionShareCardView(summary: summary)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = ShareCardLayout.renderScale
        renderer.proposedSize = ProposedViewSize(
            width: ShareCardLayout.width,
            height: ShareCardLayout.height
        )

        return renderer.uiImage
    }
}

// MARK: - Preview

#Preview("Share Card") {
    let sampleActual: [ActualStateSnapshot] = (0..<12).map { i in
        let t = Double(i) / 11.0
        return ActualStateSnapshot(
            normalizedTime: t,
            energy: 0.25 + 0.45 * sin(t * .pi),
            heartRate: 70 + 30 * sin(t * .pi)
        )
    }

    let sampleTracks: [TrackResonanceData] = [
        TrackResonanceData(
            songTitle: "Midnight City",
            artistName: "M83",
            songAppleMusicId: "abc",
            alignment: 0.92,
            hrDirectionMatch: true,
            completionRatio: 1.0,
            wasSkipped: false
        ),
    ]

    let result = ResonanceScoreResult(
        overallScore: 82,
        biometricScore: 85,
        engagementScore: 78,
        perTrackData: sampleTracks,
        sessionDuration: 2400,
        tracksPlayed: 12,
        bestTrack: sampleTracks.first
    )

    ScrollView {
        SessionShareCardView(
            summary: SessionSummaryData(
                sessionDuration: 2400,
                songsPlayed: 12,
                songsSkipped: 2,
                skipRate: 0.167,
                hrvImproved: true,
                hrvDelta: 3.5,
                bestFitSong: (title: "Midnight City", artist: "M83"),
                averageBPM: 95,
                sessionQualityScore: 0.82,
                resonanceScore: result,
                actualStateSnapshots: sampleActual,
                highlightTrack: HighlightTrack(
                    title: "Midnight City",
                    artist: "M83",
                    appleMusicId: "abc",
                    alignmentScore: 0.92,
                    heartRate: 96,
                    artworkData: nil
                )
            )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .padding()
    }
    .background(Color.black)
}

#endif
