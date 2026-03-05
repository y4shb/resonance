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

    // Accessibility
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Track whether user is actively scrubbing the slider
    @State private var isScrubbing: Bool = false
    @State private var scrubProgress: Double = 0.0
    @State private var showMoodInput: Bool = false
    @State private var isExplanationExpanded: Bool = false

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

                        hrvZoneBar

                        stateInfoBar

                        activePlaylistBar
                    }
                    .padding(.horizontal)
                    .background(artworkBackgroundGradient)
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
                    .accessibilityLabel("AI Select Next Song")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMoodInput = true
                    } label: {
                        Image(systemName: "face.smiling")
                    }
                    .accessibilityLabel("Set Mood")
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
        .accessibilityLabel("Album art: \(viewModel.currentSong.title) by \(viewModel.currentSong.artistName)")
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
            .accessibilityLabel("Playback progress")
            .accessibilityValue("\(viewModel.currentTime.formattedMinutesSeconds) of \(viewModel.duration.formattedMinutesSeconds)")

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
            .accessibilityLabel("Previous track")

            // Play/Pause button
            Button(action: { viewModel.togglePlayPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

            // Next button
            Button(action: { viewModel.skip() }) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("Skip to next track")
        }
    }

    // MARK: - Explanation Bar (Progressive Disclosure)

    private var explanationBar: some View {
        Group {
            if let explanation = viewModel.currentExplanation {
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: {
                        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)) {
                            isExplanationExpanded.toggle()
                        }
                    }) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.blue)
                                .font(.caption)
                                .padding(.top, 2)

                            Text(explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(isExplanationExpanded ? nil : 1)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: isExplanationExpanded ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.tertiary)
                                .font(.caption2)
                                .padding(.top, 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("AI explanation: \(explanation)")
                .accessibilityHint(isExplanationExpanded ? "Tap to collapse" : "Tap to expand")
            }
        }
    }

    // MARK: - HRV Zone Indicator

    private var hrvZoneBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(hrvZoneColor)
                .frame(width: 8, height: 8)
                .shadow(color: hrvZoneColor.opacity(0.6), radius: 4)

            Text(hrvZoneName)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .accessibilityLabel("Heart rate variability zone: \(hrvZoneName)")
    }

    /// Returns the HRV zone color based on current stress level
    private var hrvZoneColor: Color {
        let stress = stateEngine.currentState.stress
        if stress < 0.35 {
            return .green      // Recovered / relaxed
        } else if stress < 0.65 {
            return .yellow     // Normal / active
        } else {
            return .red        // Stressed / elevated
        }
    }

    /// Returns the HRV zone name based on current stress level
    private var hrvZoneName: String {
        let stress = stateEngine.currentState.stress
        if stress < 0.35 {
            return "Recovered"
        } else if stress < 0.65 {
            return "Normal"
        } else {
            return "Stressed"
        }
    }

    // MARK: - Album Art Background Gradient

    private var artworkBackgroundGradient: some View {
        Group {
            if let accentColor = viewModel.artworkAccentColor {
                LinearGradient(
                    colors: [accentColor.opacity(0.15), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.6), value: viewModel.artworkAccentColor)
            } else {
                Color.clear
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
