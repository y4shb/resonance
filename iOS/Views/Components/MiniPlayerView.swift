//
//  MiniPlayerView.swift
//  Resonance
//
//  Persistent mini player displayed as a tab bar bottom accessory.
//  Shows current track info (title, artist, album art thumbnail)
//  and transport controls (play/pause, skip). Tapping the track
//  info area navigates to the full Now Playing tab.
//
//  Uses iOS 26 Liquid Glass styling via `.glassEffect` when available,
//  with an `.ultraThinMaterial` fallback for earlier versions.
//

import SwiftUI
import MusicKit

// MARK: - Mini Player View

struct MiniPlayerView: View {
    // MARK: - Properties

    @Bindable var viewModel: NowPlayingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Callback invoked when the user taps the track info area to navigate to Now Playing.
    var onTapNavigate: () -> Void

    // Haptic feedback triggers
    @State private var playPauseTrigger = 0
    @State private var skipTrigger = 0

    // MARK: - Body

    var body: some View {
        expandedLayout
    }

    // MARK: - Expanded Layout

    /// Artwork size for the mini player thumbnail.
    private let artworkSize: CGFloat = 48

    /// Full-width layout shown when the tab bar is fully visible.
    /// Displays album art thumbnail, song info, and transport controls.
    /// The entire row (except transport buttons) navigates to Now Playing on tap.
    private var expandedLayout: some View {
        VStack(spacing: 0) {
            // Accent progress line at the top edge
            ResonanceProgressBar(
                progress: viewModel.playbackProgress,
                color: ResonanceColors.accent,
                height: 2
            )
            .animation(reduceMotion ? .none : .linear(duration: 0.5), value: viewModel.playbackProgress)
            .accessibilityLabel("Playback progress")
            .accessibilityValue("\(Int(max(0, min(1, viewModel.playbackProgress)) * 100)) percent")

            HStack(spacing: 12) {
                // Album art thumbnail (slightly larger)
                artworkThumbnail
                    .frame(width: artworkSize, height: artworkSize)

                // Song info
                songInfoSection

                Spacer(minLength: 4)

                // Transport controls (play/pause + skip)
                transportControls
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .glassEffect(.regular)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                onTapNavigate()
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mini Player")
    }

    // MARK: - Artwork Thumbnail

    private var artworkThumbnail: some View {
        Group {
            if let artwork = viewModel.currentSong.artwork {
                // Request thumbnail-sized artwork to avoid loading full-resolution images
                ArtworkImage(artwork, width: artworkSize, height: artworkSize)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Song Info Section

    private var songInfoSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.currentSong.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Text(viewModel.currentSong.artistName)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.currentSong.title) by \(viewModel.currentSong.artistName)")
        .accessibilityHint("Tap to open Now Playing")
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 16) {
            playPauseButton(fontSize: .title3)

            Button(action: {
                skipTrigger += 1
                viewModel.skip()
            }) {
                Image(systemName: "forward.fill")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("Skip to next track")
            .accessibilityHint("Skips to the next song in the queue")
            .sensoryFeedback(.impact(weight: .light), trigger: skipTrigger)
        }
    }

    // MARK: - Play/Pause Button

    /// Reusable play/pause button scaled to the given font size.
    private func playPauseButton(fontSize: Font) -> some View {
        Button(action: {
            playPauseTrigger += 1
            viewModel.togglePlayPause()
        }) {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(fontSize)
                .foregroundStyle(.primary)
        }
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
        .accessibilityHint(viewModel.isPlaying ? "Pauses the current track" : "Resumes playback")
        .sensoryFeedback(.impact(weight: .medium), trigger: playPauseTrigger)
    }
}

// MARK: - Preview

#Preview {
    TabView {
        Text("Content")
            .tabItem { Label("Home", systemImage: "house") }
    }
    .tabViewBottomAccessory {
        MiniPlayerView(
            viewModel: NowPlayingViewModel(musicService: MusicKitService()),
            onTapNavigate: {}
        )
    }
}
