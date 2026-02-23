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
    @ObservedObject var stateEngine: StateEngine

    // Track whether user is actively scrubbing the slider
    @State private var isScrubbing: Bool = false
    @State private var scrubProgress: Double = 0.0
    @State private var showMoodInput: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.activePlaylistName == nil && viewModel.currentSong == .placeholder {
                    ContentUnavailableView(
                        "No Playlist Selected",
                        systemImage: "music.note.list",
                        description: Text("Select a playlist from the Playlists tab to start your AI DJ session.")
                    )
                } else {
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

                        explanationBar

                        stateInfoBar

                        activePlaylistBar
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Resonance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.requestAISelection()
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .disabled(viewModel.activePlaylistName == nil)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMoodInput = true
                    } label: {
                        Image(systemName: "face.smiling")
                    }
                }
            }
            .sheet(isPresented: $showMoodInput) {
                MoodInputView(stateEngine: stateEngine)
            }
            .alert("Playback Error", isPresented: showErrorBinding) {
                Button("Retry") {
                    viewModel.errorMessage = nil
                    viewModel.togglePlayPause()
                }
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
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
                    .fill(.ultraThinMaterial)
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
                Text((isScrubbing ? scrubProgress * viewModel.duration : viewModel.currentTime)
                    .formattedMinutesSeconds)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                Spacer()

                Text(viewModel.duration.formattedMinutesSeconds)
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

    // MARK: - Explanation Bar

    private var explanationBar: some View {
        Group {
            if let explanation = viewModel.currentExplanation {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.blue)
                        .font(.caption)
                        .padding(.top, 2)

                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - State Info Bar

    private var stateInfoBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.secondary)
                .font(.caption)

            Text(stateEngine.currentState.context.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("·")
                .foregroundStyle(.secondary)

            Text(stateEngine.currentState.inferredNeed.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.tint)

            Spacer()

            Text("\(Int(stateEngine.currentState.confidence * 100))%")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NowPlayingView(
        viewModel: NowPlayingViewModel(musicService: MusicKitService()),
        stateEngine: StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
    )
}
