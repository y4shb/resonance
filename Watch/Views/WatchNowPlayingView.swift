//
//  WatchNowPlayingView.swift
//  Resonance Watch
//
//  watchOS Now Playing view with song info, playback controls, and explanation
//

import SwiftUI

// MARK: - Watch Now Playing View

struct WatchNowPlayingView: View {
    @ObservedObject var connectivityService: PhoneConnectivityService

    var body: some View {
        if let nowPlaying = connectivityService.currentNowPlaying {
            nowPlayingContent(nowPlaying)
        } else {
            waitingView
        }
    }

    // MARK: - Now Playing Content

    private func nowPlayingContent(_ nowPlaying: NowPlayingPacket) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                // Album Art
                albumArtView(data: nowPlaying.artworkData)

                // Song Info
                songInfoSection(nowPlaying)

                // Progress Bar
                progressBar(progress: nowPlaying.progress, duration: nowPlaying.duration)

                // Playback Controls
                playbackControls(isPlaying: nowPlaying.isPlaying)

                // Explanation
                if let explanation = nowPlaying.explanation, !explanation.isEmpty {
                    explanationView(explanation)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("AI DJ")
    }

    // MARK: - Album Art

    private func albumArtView(data: Data?) -> some View {
        Group {
            if let artworkData = data,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 10))
                        .frame(width: 80, height: 80)
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Song Info

    private func songInfoSection(_ nowPlaying: NowPlayingPacket) -> some View {
        VStack(spacing: 2) {
            Text(nowPlaying.songTitle)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(nowPlaying.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Progress Bar

    private func progressBar(progress: Double, duration: TimeInterval) -> some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                        .frame(height: 4)

                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.blue)
                        .frame(width: geometry.size.width * max(0, min(1, progress)), height: 4)
                }
            }
            .frame(height: 4)

            // Time labels
            HStack {
                Text(formatTime(duration * progress))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Playback Controls

    private func playbackControls(isPlaying: Bool) -> some View {
        HStack(spacing: 16) {
            // Previous
            Button {
                connectivityService.sendPlaybackCommand(PlaybackCommand(command: .previous))
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button {
                let command: PlaybackCommand.Command = isPlaying ? .pause : .play
                connectivityService.sendPlaybackCommand(PlaybackCommand(command: command))
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            // Skip
            Button {
                connectivityService.sendPlaybackCommand(PlaybackCommand(command: .skip))
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Explanation

    private func explanationView(_ explanation: String) -> some View {
        Text(explanation)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 4)
    }

    // MARK: - Waiting View

    private var waitingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            Text("AI DJ")
                .font(.headline)

            if connectivityService.isPhoneReachable {
                Text("Waiting for music...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "iphone.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("iPhone not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("AI DJ")
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#Preview("Now Playing") {
    WatchNowPlayingView(connectivityService: PhoneConnectivityService())
}
