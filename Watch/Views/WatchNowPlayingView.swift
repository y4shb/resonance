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
    @ObservedObject var crownHandler: CrownHandler
    @State private var crownRotation: Double = 0.0
    @FocusState private var isCrownFocused: Bool

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

                // DJ Mode Energy Gauge
                if crownHandler.isDJModeActive {
                    HStack(spacing: 4) {
                        Image(systemName: "minus")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.quaternary)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.orange)
                                    .frame(
                                        width: geometry.size.width * ((crownHandler.energyAdjustment + 1.0) / 2.0),
                                        height: 4
                                    )
                            }
                        }
                        .frame(height: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .transition(.opacity.combined(with: .scale))
                }

                // Progress Bar
                progressBar(progress: nowPlaying.progress, duration: nowPlaying.duration)

                // State Info Row
                if let state = connectivityService.currentState {
                    HStack(spacing: 8) {
                        if let hr = state.heartRate {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                                Text("\(Int(hr))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let context = state.currentContext {
                            Text(context)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Playback Controls
                playbackControls(isPlaying: nowPlaying.isPlaying)

                // DJ Mode Toggle
                Button {
                    crownHandler.toggleDJMode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: crownHandler.isDJModeActive ? "dial.high.fill" : "dial.low")
                            .font(.caption)
                        Text(crownHandler.isDJModeActive ? "DJ On" : "DJ Mode")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .tint(crownHandler.isDJModeActive ? .orange : .gray)

                // Explanation
                if let explanation = nowPlaying.explanation, !explanation.isEmpty {
                    explanationView(explanation)
                }

                // Mood Input
                NavigationLink {
                    WatchMoodInputView(connectivityService: connectivityService)
                } label: {
                    Label("Set Mood", systemImage: "face.smiling")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
            }
            .padding(.horizontal, 4)
        }
        .digitalCrownRotation(
            $crownRotation,
            from: -CrownConstants.maxAdjustment,
            through: CrownConstants.maxAdjustment,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .focusable(true)
        .focused($isCrownFocused)
        .onChange(of: crownRotation) { _, newValue in
            crownHandler.handleCrownRotation(value: newValue)
        }
        .onAppear { isCrownFocused = true }
        .animation(.easeInOut(duration: 0.3), value: crownHandler.isDJModeActive)
        .navigationTitle("Resonance")
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
                Text((duration * progress).formattedMinutesSeconds)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(duration.formattedMinutesSeconds)
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
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button {
                let command: PlaybackCommand.Command = isPlaying ? .pause : .play
                connectivityService.sendPlaybackCommand(PlaybackCommand(command: command))
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            // Skip
            Button {
                connectivityService.sendPlaybackCommand(PlaybackCommand(command: .skip))
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
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

            Text("Resonance")
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
        .navigationTitle("Resonance")
    }

}

// MARK: - Preview

#Preview("Now Playing") {
    let service = PhoneConnectivityService()
    WatchNowPlayingView(
        connectivityService: service,
        crownHandler: CrownHandler(connectivityService: service)
    )
}
