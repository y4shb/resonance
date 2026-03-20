//
//  BookmarkTimelineView.swift
//  Resonance
//
//  Post-session bookmark timeline visualization. Shows bookmarked moments
//  on a timeline bar with detailed cards for each bookmark.
//

#if os(iOS)

import SwiftUI

// MARK: - Bookmark Timeline View

struct BookmarkTimelineView: View {
    let bookmarks: [SonicBookmarkData]
    let sessionDuration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline)

                Text("Bookmarked Moments")
                    .font(.headline)

                Spacer()

                Text("\(bookmarks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                    )
            }

            // Timeline bar with pin markers
            if sessionDuration > 0 {
                timelineBar
            }

            // Bookmark cards
            ForEach(bookmarks) { bookmark in
                BookmarkCard(bookmark: bookmark)
            }
        }
    }

    // MARK: - Timeline Bar

    private var timelineBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Timeline track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .position(x: geo.size.width / 2, y: 20)

                // Bookmark pins
                ForEach(bookmarks) { bookmark in
                    let fraction = min(1.0, max(0.0, bookmark.playbackPosition / sessionDuration))
                    let xPosition = geo.size.width * CGFloat(fraction)

                    VStack(spacing: 2) {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)

                        Circle()
                            .fill(.yellow)
                            .frame(width: 6, height: 6)
                    }
                    .position(x: xPosition, y: 12)
                }
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 4)
    }
}

// MARK: - Bookmark Card

struct BookmarkCard: View {
    let bookmark: SonicBookmarkData

    var body: some View {
        HStack(spacing: 12) {
            // Trigger source icon
            triggerIcon
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color(.tertiarySystemFill))
                )

            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.songTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(bookmark.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Metadata column
            VStack(alignment: .trailing, spacing: 2) {
                // Playback position
                Text(formatTime(bookmark.playbackPosition))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                // Heart rate if available
                if let hr = bookmark.heartRate {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                        Text("\(Int(hr))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(bookmark.songTitle) by \(bookmark.artistName), "
            + "bookmarked at \(formatTime(bookmark.playbackPosition))"
            + (bookmark.heartRate.map { ", heart rate \(Int($0))" } ?? "")
        )
    }

    // MARK: - Trigger Icon

    private var triggerIcon: some View {
        Group {
            switch bookmark.triggerSource {
            case .iphoneShake:
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.blue)
            case .iphoneButton:
                Image(systemName: "hand.tap.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            case .watchDoubleTap:
                Image(systemName: "applewatch")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .watchButton:
                Image(systemName: "applewatch")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview("Bookmark Timeline") {
    BookmarkTimelineView(
        bookmarks: [
            SonicBookmarkData(
                id: UUID(),
                timestamp: Date(),
                triggerSource: .iphoneShake,
                songTitle: "Blinding Lights",
                artistName: "The Weeknd",
                songAppleMusicId: "1234",
                playbackPosition: 45,
                songDuration: 200,
                heartRate: 82,
                hrv: 45,
                arousal: 0.6,
                energy: 0.7,
                stress: 0.3,
                valence: 0.8,
                activityContext: "workout",
                inferredNeed: "energize"
            ),
            SonicBookmarkData(
                id: UUID(),
                timestamp: Date(),
                triggerSource: .watchDoubleTap,
                songTitle: "Starboy",
                artistName: "The Weeknd",
                songAppleMusicId: "5678",
                playbackPosition: 120,
                songDuration: 200,
                heartRate: 95,
                hrv: 38,
                arousal: 0.8,
                energy: 0.9,
                stress: 0.2,
                valence: 0.9,
                activityContext: "workout",
                inferredNeed: "maintain"
            ),
        ],
        sessionDuration: 3600
    )
    .padding()
}

#endif
