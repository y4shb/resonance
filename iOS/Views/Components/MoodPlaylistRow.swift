//
//  MoodPlaylistRow.swift
//  Resonance
//
//  A row component for auto-generated mood playlists. Visually distinct
//  from user playlists with a brain/mood icon and a song count badge.
//

import SwiftUI

// MARK: - Mood Playlist Row

/// Displays a single `MoodPlaylist` entry with an icon, name, subtitle,
/// and a song count badge.
///
/// Used within the playlist browser to differentiate Resonance-generated
/// mood playlists from user-created Apple Music playlists.
struct MoodPlaylistRow: View {

    // MARK: - Properties

    /// The mood playlist to display.
    let playlist: MoodPlaylist

    /// Number of songs matching this mood's predicate.
    let songCount: Int

    // MARK: - Constants

    /// Corner radius for the mood icon background.
    private static let iconCornerRadius: CGFloat = 10

    /// Font size for the SF Symbol inside the mood icon.
    private static let iconFontSize: CGFloat = 20

    /// Opacity for the gradient badge background.
    private static let badgeBackgroundOpacity: Double = 0.8

    // MARK: - Body

    var body: some View {
        HStack(spacing: 14) {
            iconView

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(playlist.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if songCount > 0 {
                songCountBadge
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(playlist.displayName), \(songCount) \(songCount == 1 ? "song" : "songs")"
        )
        .accessibilityHint("Tap to browse this mood playlist")
    }

    // MARK: - Song Count Badge

    private var songCountBadge: some View {
        Text("\(songCount)")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                resolvedAccentColor.opacity(Self.badgeBackgroundOpacity),
                in: Capsule()
            )
    }

    // MARK: - Icon

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.iconCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [resolvedAccentColor.opacity(0.7), resolvedAccentColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: UIConstants.ArtworkSize.small,
                    height: UIConstants.ArtworkSize.small
                )

            Image(systemName: playlist.icon)
                .font(.system(size: Self.iconFontSize))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Color Resolution

    /// Resolves the playlist's string-based accent color to a SwiftUI `Color`.
    private var resolvedAccentColor: Color {
        switch playlist.accentColor {
        case "teal":   return .teal
        case "blue":   return .blue
        case "red":    return .red
        case "yellow": return .yellow
        case "purple": return .purple
        case "cyan":   return .cyan
        default:       return .blue
        }
    }
}
