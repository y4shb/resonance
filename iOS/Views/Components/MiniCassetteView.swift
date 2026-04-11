//
//  MiniCassetteView.swift
//  Resonance
//
//  Lightweight cassette tape view for use in lists, grids, and carousels.
//  Album artwork fills the cassette shell with circular reel hub cutouts.
//  Static reels (no animation) for performance in scrolling contexts.
//
//  Proportions match CassettePlayerView (1.57:1 width:height).
//  Uses .blendMode(.destinationOut) + .compositingGroup() for reel cutouts.
//

import SwiftUI
import MusicKit

// MARK: - Mini Cassette View

struct MiniCassetteView: View {
    let artwork: MusicKit.Artwork?
    let title: String
    let subtitle: String
    let accentColor: Color
    let width: CGFloat

    init(
        artwork: MusicKit.Artwork? = nil,
        title: String = "",
        subtitle: String = "",
        accentColor: Color = ResonanceColors.accent,
        width: CGFloat = 240
    ) {
        self.artwork = artwork
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.width = width
    }

    // MARK: - Dimensions (proportional to width)

    private var height: CGFloat { width / 1.57 }
    private var reelDiameter: CGFloat { height * 0.44 }
    private var reelY: CGFloat { height * 0.50 }
    private var leftReelX: CGFloat { width * 0.24 }
    private var rightReelX: CGFloat { width * 0.76 }
    private var hubRadius: CGFloat { reelDiameter * 0.14 }
    private var isCompact: Bool { width < 120 }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dark interior (visible through reel cutouts)
            RoundedRectangle(cornerRadius: isCompact ? 4 : 6)
                .fill(Color(red: 0.03, green: 0.03, blue: 0.05))

            // Static reel hubs
            if !isCompact {
                reelHubs
            }

            // Album art with cutouts
            albumArtWithCutouts

            // Overlay details
            cassetteOverlays

            // Title overlay at bottom
            if !title.isEmpty {
                titleOverlay
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 4 : 6))
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
    }

    // MARK: - Album Art with Reel Cutouts

    private var albumArtWithCutouts: some View {
        ZStack {
            // Full-bleed album art
            Group {
                if let artwork = artwork {
                    ArtworkImage(artwork, width: width, height: width)
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                        .overlay(
                            // Subtle darkening for depth
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.08),
                                    .black.opacity(0.02),
                                    .black.opacity(0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    // Gradient placeholder
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.35),
                            Color(red: 0.12, green: 0.12, blue: 0.15),
                            accentColor.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }

            // Punch out left reel
            Circle()
                .fill(.black)
                .frame(width: reelDiameter + 2, height: reelDiameter + 2)
                .position(x: leftReelX, y: reelY)
                .blendMode(.destinationOut)

            // Punch out right reel
            Circle()
                .fill(.black)
                .frame(width: reelDiameter + 2, height: reelDiameter + 2)
                .position(x: rightReelX, y: reelY)
                .blendMode(.destinationOut)

            // Head slot
            if !isCompact {
                Capsule()
                    .fill(.black)
                    .frame(width: width * 0.15, height: 3)
                    .position(x: width / 2, y: height - 6)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    // MARK: - Static Reel Hubs

    private var reelHubs: some View {
        ZStack {
            // Left hub
            Circle()
                .fill(Color(red: 0.30, green: 0.30, blue: 0.34))
                .frame(width: hubRadius * 2, height: hubRadius * 2)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.04, green: 0.04, blue: 0.06))
                        .frame(width: hubRadius * 0.7, height: hubRadius * 0.7)
                )
                .position(x: leftReelX, y: reelY)

            // Right hub
            Circle()
                .fill(Color(red: 0.30, green: 0.30, blue: 0.34))
                .frame(width: hubRadius * 2, height: hubRadius * 2)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.04, green: 0.04, blue: 0.06))
                        .frame(width: hubRadius * 0.7, height: hubRadius * 0.7)
                )
                .position(x: rightReelX, y: reelY)
        }
    }

    // MARK: - Cassette Overlays

    private var cassetteOverlays: some View {
        ZStack {
            // Chrome bezels around reel windows
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: isCompact ? 0.5 : 1)
                .frame(width: reelDiameter + 3, height: reelDiameter + 3)
                .position(x: leftReelX, y: reelY)

            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: isCompact ? 0.5 : 1)
                .frame(width: reelDiameter + 3, height: reelDiameter + 3)
                .position(x: rightReelX, y: reelY)

            // Label at top
            if !isCompact {
                VStack {
                    Text("RESONANCE")
                        .font(.system(size: max(5, width * 0.025), weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .padding(.top, height * 0.05)
                    Spacer()
                }
            }

            // Glass sheen
            LinearGradient(
                colors: [.white.opacity(0.06), .clear, .white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: isCompact ? 4 : 6))

            // Shell border
            RoundedRectangle(cornerRadius: isCompact ? 4 : 6)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)

            // Accent glow
            RoundedRectangle(cornerRadius: isCompact ? 4 : 6)
                .stroke(accentColor.opacity(0.08), lineWidth: 0.5)
                .blur(radius: 1)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    // MARK: - Title Overlay

    private var titleOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: max(8, width * 0.04), weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.95))

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: max(6, width * 0.03), weight: .regular, design: .monospaced))
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, isCompact ? 2 : 4)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Preview

#Preview("Mini Cassette - Default") {
    ZStack {
        Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
        VStack(spacing: 20) {
            MiniCassetteView(
                title: "Blinding Lights",
                subtitle: "The Weeknd",
                width: 260
            )

            MiniCassetteView(
                title: "Left and Right",
                subtitle: "Charlie Puth",
                accentColor: .purple,
                width: 180
            )

            HStack(spacing: 12) {
                MiniCassetteView(title: "Song", width: 100)
                MiniCassetteView(title: "Song", width: 80)
            }
        }
    }
}
