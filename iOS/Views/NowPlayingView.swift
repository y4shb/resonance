//
//  NowPlayingView.swift
//  Resonance
//
//  Displays the currently playing track with album artwork, song info,
//  playback progress, and transport controls.
//

import SwiftUI
import MusicKit

// MARK: - Now Playing View

struct NowPlayingView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: NowPlayingViewModel

    // Track whether user is actively scrubbing the slider
    @State private var isScrubbing: Bool = false
    @State private var scrubProgress: Double = 0.0

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()

                artworkView
                    .padding(.bottom, 24)

                songInfoView
                    .padding(.bottom, 28)

                progressView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                transportControls
                    .padding(.bottom, 24)

                Spacer()

                activePlaylistBar
            }
            .padding(.horizontal)
            .navigationTitle("AI DJ")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Playback Error", isPresented: showErrorBinding) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Error Binding

    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    // MARK: - Artwork View

    private var artworkView: some View {
        Group {
            if let artwork = viewModel.currentSong.artwork {
                ArtworkImage(artwork, width: UIConstants.ArtworkSize.large)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            } else {
                // Placeholder artwork
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.4), .purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: UIConstants.ArtworkSize.large,
                        height: UIConstants.ArtworkSize.large
                    )
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.7))
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
        }
    }

    // MARK: - Song Info View

    private var songInfoView: some View {
        VStack(spacing: 6) {
            Text(viewModel.currentSong.title)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            Text(viewModel.currentSong.artistName)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 4) {
            Slider(
                value: isScrubbing
                    ? $scrubProgress
                    : Binding(
                        get: { viewModel.playbackProgress },
                        set: { viewModel.playbackProgress = $0 }
                    ),
                in: 0...1,
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if editing {
                        scrubProgress = viewModel.playbackProgress
                    } else {
                        viewModel.seek(to: scrubProgress)
                    }
                }
            )
            .tint(.blue)

            HStack {
                Text(NowPlayingViewModel.formatTime(
                    isScrubbing ? scrubProgress * viewModel.duration : viewModel.currentTime
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                Spacer()

                Text(NowPlayingViewModel.formatTime(viewModel.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 40) {
            // Previous button
            Button(action: { viewModel.previous() }) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }

            // Play/Pause button
            Button(action: { viewModel.togglePlayPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
            }

            // Next button
            Button(action: { viewModel.skip() }) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Active Playlist Bar

    private var activePlaylistBar: some View {
        Group {
            if let playlistName = viewModel.activePlaylistName {
                HStack {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)

                    Text("Playing from: \(playlistName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NowPlayingView(
        viewModel: NowPlayingViewModel(musicService: MusicKitService())
    )
}
