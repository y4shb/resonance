//
//  VinylMiniPlayerView.swift
//  Resonance
//
//  Compact spinning vinyl record mini player. Replaces the standard
//  MiniPlayerView with a tiny spinning record, progress arc, song info,
//  and transport controls. Uses iOS 26 Liquid Glass styling.
//

import SwiftUI
import MusicKit

// MARK: - Vinyl Mini Player View

struct VinylMiniPlayerView: View {
    // MARK: - Properties

    @Bindable var viewModel: NowPlayingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Callback invoked when the user taps the track info area to navigate to Now Playing.
    var onTapNavigate: () -> Void

    // Haptic feedback triggers
    @State private var playPauseTrigger = 0
    @State private var skipTrigger = 0

    // Mini record rotation
    @State private var miniRotationController = VinylRotationController()

    private let miniRecordSize: CGFloat = VinylConstants.recordDiameterMini

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Tiny spinning record with progress arc
            miniRecordWithProgress

            // Song info
            songInfoSection

            Spacer(minLength: 4)

            // Transport controls (play/pause + skip)
            transportControls
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                onTapNavigate()
            }
        )
        .onChange(of: viewModel.isPlaying) { _, playing in
            miniRotationController.sync(with: playing)
        }
        .onAppear {
            miniRotationController.sync(with: viewModel.isPlaying)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mini Player")
    }

    // MARK: - Mini Record with Progress Arc

    private var miniRecordWithProgress: some View {
        TimelineView(.animation(paused: !miniRotationController.isPlaying)) { timeline in
            ZStack {
                // Progress arc behind the record
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, viewModel.playbackProgress))))
                    .stroke(
                        ResonanceColors.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: miniRecordSize + 6, height: miniRecordSize + 6)
                    .rotationEffect(.degrees(-90))

                // Track background arc
                Circle()
                    .stroke(
                        Color.white.opacity(0.1),
                        lineWidth: 2
                    )
                    .frame(width: miniRecordSize + 6, height: miniRecordSize + 6)

                // Tiny spinning vinyl record
                VinylRecordView(
                    artwork: viewModel.currentSong.artwork,
                    diameter: miniRecordSize,
                    rotationDegrees: miniRotationController.degrees(at: timeline.date),
                    isMini: true
                )
            }
        }
        .frame(width: miniRecordSize + 8, height: miniRecordSize + 8)
        .accessibilityLabel("Playback progress: \(Int(viewModel.playbackProgress * 100)) percent")
    }

    // MARK: - Song Info

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
            Button(action: {
                playPauseTrigger += 1
                viewModel.togglePlayPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
            .sensoryFeedback(.impact(weight: .medium), trigger: playPauseTrigger)

            Button(action: {
                skipTrigger += 1
                viewModel.skip()
            }) {
                Image(systemName: "forward.fill")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("Skip to next track")
            .sensoryFeedback(.impact(weight: .light), trigger: skipTrigger)
        }
    }
}

// MARK: - Preview

#Preview {
    TabView {
        Text("Content")
            .tabItem { Label("Home", systemImage: "house") }
    }
    .tabViewBottomAccessory {
        VinylMiniPlayerView(
            viewModel: NowPlayingViewModel(musicService: MusicKitService()),
            onTapNavigate: {}
        )
    }
}
