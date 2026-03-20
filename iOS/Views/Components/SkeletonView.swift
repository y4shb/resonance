//
//  SkeletonView.swift
//  Resonance
//
//  Skeleton loading placeholders that replace spinners for perceived-faster loading.
//  Uses shimmer animations over redacted content to indicate loading state.
//
//  Timing strategy:
//  - <200ms: No indicator shown
//  - 200ms-1s: Subtle pulse animation
//  - 1s-3s: Full skeleton with shimmer
//  - >3s: Skeleton + descriptive text
//

import SwiftUI

// MARK: - Shimmer Modifier

/// Applies an animated shimmer gradient overlay to any view, creating a
/// "loading" shine effect. Works in both light and dark mode by adapting
/// gradient colors to the current color scheme.
struct ShimmerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(shimmerOverlay)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2.0
                }
            }
    }

    @ViewBuilder
    private var shimmerOverlay: some View {
        if reduceMotion {
            // For reduced-motion users, show a subtle static pulse instead
            Color.clear
        } else {
            GeometryReader { geometry in
                let shimmerColor = colorScheme == .dark
                    ? Color.white.opacity(0.12)
                    : Color.white.opacity(0.6)

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: shimmerColor, location: 0.3),
                        .init(color: shimmerColor, location: 0.5),
                        .init(color: .clear, location: 0.7),
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 2)
                .offset(x: geometry.size.width * phase)
            }
            .clipped()
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds a shimmer loading animation overlay to the view.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shapes

/// A rounded rectangle placeholder used as a building block for skeleton layouts.
struct SkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 4) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(fillColor)
            .frame(width: width, height: height)
    }

    private var fillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }
}

// MARK: - Skeleton Playlist Row

/// Mimics the layout of PlaylistRow with placeholder shapes instead of real data.
struct SkeletonPlaylistRow: View {
    var body: some View {
        HStack(spacing: 14) {
            // Artwork placeholder
            SkeletonShape(
                width: UIConstants.ArtworkSize.small,
                height: UIConstants.ArtworkSize.small,
                cornerRadius: 6
            )

            // Text lines placeholder
            VStack(alignment: .leading, spacing: 6) {
                SkeletonShape(width: 140, height: 14, cornerRadius: 4)
                SkeletonShape(width: 80, height: 10, cornerRadius: 3)
            }

            Spacer()

            // Chevron placeholder
            SkeletonShape(width: 8, height: 14, cornerRadius: 2)
        }
        .padding(.vertical, 4)
        .shimmer()
    }
}

// MARK: - Skeleton Playlist Card

/// A full skeleton view that replaces the playlist browser loading spinner.
/// Shows multiple skeleton rows inside a list-like layout.
struct SkeletonPlaylistCard: View {
    let rowCount: Int

    init(rowCount: Int = 6) {
        self.rowCount = rowCount
    }

    var body: some View {
        List {
            Section {
                ForEach(0..<rowCount, id: \.self) { _ in
                    SkeletonPlaylistRow()
                }
            } header: {
                SkeletonShape(width: 80, height: 10, cornerRadius: 3)
                    .shimmer()
            }
        }
        .listStyle(.insetGrouped)
        .disabled(true)
        .accessibilityLabel("Loading playlists")
    }
}

// MARK: - Skeleton Now Playing Card

/// Skeleton placeholder that mimics the NowPlayingView layout while content loads.
struct SkeletonNowPlayingCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Artwork placeholder
            artworkSkeleton
                .padding(.bottom, 24)

            // Song info placeholder
            songInfoSkeleton
                .padding(.bottom, 28)

            // Progress bar placeholder
            progressSkeleton
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            // Transport controls placeholder
            transportSkeleton
                .padding(.bottom, 24)

            Spacer()

            // Bottom bars placeholder
            bottomBarsSkeleton
        }
        .padding(.horizontal)
        .shimmer()
        .accessibilityLabel("Loading now playing")
    }

    // MARK: - Artwork Skeleton

    private var artworkSkeleton: some View {
        SkeletonShape(
            width: UIConstants.ArtworkSize.large,
            height: UIConstants.ArtworkSize.large,
            cornerRadius: 12
        )
    }

    // MARK: - Song Info Skeleton

    private var songInfoSkeleton: some View {
        VStack(spacing: 8) {
            SkeletonShape(width: 200, height: 22, cornerRadius: 6)
            SkeletonShape(width: 140, height: 16, cornerRadius: 4)
        }
    }

    // MARK: - Progress Skeleton

    private var progressSkeleton: some View {
        VStack(spacing: 6) {
            SkeletonShape(height: 4, cornerRadius: 2)
            HStack {
                SkeletonShape(width: 36, height: 10, cornerRadius: 3)
                Spacer()
                SkeletonShape(width: 36, height: 10, cornerRadius: 3)
            }
        }
    }

    // MARK: - Transport Skeleton

    private var transportSkeleton: some View {
        HStack(spacing: 40) {
            SkeletonShape(width: 28, height: 28, cornerRadius: 6)
            SkeletonShape(width: 56, height: 56, cornerRadius: 28)
            SkeletonShape(width: 28, height: 28, cornerRadius: 6)
        }
    }

    // MARK: - Bottom Bars Skeleton

    private var bottomBarsSkeleton: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                SkeletonShape(width: 14, height: 14, cornerRadius: 3)
                SkeletonShape(width: 200, height: 12, cornerRadius: 3)
                Spacer()
            }
            .padding(.horizontal, 16)

            HStack(spacing: 6) {
                SkeletonShape(width: 8, height: 8, cornerRadius: 4)
                SkeletonShape(width: 60, height: 10, cornerRadius: 3)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Timed Skeleton View

/// Manages the loading indicator timing strategy:
/// - <200ms delay: Shows nothing (avoids flash)
/// - 200ms-1s: Subtle pulse on the skeleton
/// - 1s-3s: Full shimmer skeleton
/// - >3s: Skeleton with descriptive text
struct TimedSkeletonView<Skeleton: View>: View {
    let message: String
    @ViewBuilder let skeleton: () -> Skeleton

    @State private var showSkeleton = false
    @State private var showMessage = false
    @State private var elapsedTimer: Timer?

    var body: some View {
        Group {
            if showSkeleton {
                VStack(spacing: 0) {
                    skeleton()

                    if showMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 12)
                            .transition(.opacity)
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // Show skeleton after 200ms delay (no indicator for very fast loads)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeIn(duration: UIConstants.Animation.quick)) {
                    showSkeleton = true
                }
            }

            // Show message after 3s for long loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeIn(duration: UIConstants.Animation.standard)) {
                    showMessage = true
                }
            }
        }
        .onDisappear {
            elapsedTimer?.invalidate()
        }
    }
}

// MARK: - Preview

#Preview("Skeleton Playlist Rows") {
    NavigationStack {
        SkeletonPlaylistCard()
            .navigationTitle("Your Playlists")
    }
}

#Preview("Skeleton Now Playing") {
    SkeletonNowPlayingCard()
}

#Preview("Shimmer on Custom Content") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            SkeletonShape(width: 50, height: 50, cornerRadius: 6)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonShape(width: 160, height: 14)
                SkeletonShape(width: 100, height: 10)
            }
            Spacer()
        }
        .shimmer()
        .padding()
    }
}
