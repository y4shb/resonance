//
//  NowPlayingViewModel.swift
//  Resonance
//
//  ViewModel for the Now Playing screen. Wraps MusicKitService to provide
//  published playback state for the UI, including progress tracking via a timer.
//

import Foundation
import Combine
import MusicKit

// MARK: - Song Display Info

/// Lightweight struct representing song metadata for the UI layer.
struct SongDisplayInfo: Equatable {
    let title: String
    let artistName: String
    let albumTitle: String
    let artwork: MusicKit.Artwork?
    let duration: TimeInterval

    static let placeholder = SongDisplayInfo(
        title: "Not Playing",
        artistName: "--",
        albumTitle: "",
        artwork: nil,
        duration: 0
    )
}

// MARK: - Now Playing View Model

@MainActor
final class NowPlayingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The currently playing song's display information.
    @Published private(set) var currentSong: SongDisplayInfo = .placeholder

    /// Whether audio is currently playing.
    @Published private(set) var isPlaying: Bool = false

    /// Playback progress as a value from 0.0 to 1.0.
    @Published var playbackProgress: Double = 0.0

    /// Current playback time in seconds.
    @Published private(set) var currentTime: TimeInterval = 0

    /// Total duration of the current track in seconds.
    @Published private(set) var duration: TimeInterval = 0

    /// The name of the currently active playlist, if any.
    @Published var activePlaylistName: String?

    /// Error message to display in the UI.
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let musicService: MusicKitService
    private var watchConnectivityManager: WatchConnectivityManager?

    /// Logs playback events (skip, previous) to Core Data. Set externally after init.
    var eventLogger: EventLogger?
    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?

    // MARK: - Initialization

    init(musicService: MusicKitService) {
        self.musicService = musicService

        logDebug("NowPlayingViewModel initializing", category: .ui)

        setupBindings()
        startProgressTimer()
    }

    // MARK: - Watch Connectivity Integration

    /// Connects the WatchConnectivityManager for bidirectional sync.
    /// Call this after init to wire up Watch playback commands and now-playing sync.
    func connectWatchManager(_ manager: WatchConnectivityManager) {
        self.watchConnectivityManager = manager
        logInfo("Watch connectivity manager connected to NowPlayingViewModel", category: .watchConnectivity)

        // Watch -> Phone: handle playback commands from Watch
        manager.playbackCommands
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                self?.handleWatchPlaybackCommand(command)
            }
            .store(in: &cancellables)
    }

    private func handleWatchPlaybackCommand(_ command: PlaybackCommand) {
        logInfo("Received Watch playback command: \(command.command.rawValue)", category: .watchConnectivity)

        switch command.command {
        case .play:
            if !isPlaying { togglePlayPause() }
        case .pause:
            if isPlaying { togglePlayPause() }
        case .skip:
            skip()
        case .previous:
            previous()
        }
    }

    /// Builds a NowPlayingPacket from current state and sends it to Watch.
    private func sendNowPlayingToWatch() {
        guard let manager = watchConnectivityManager else { return }

        let packet = NowPlayingPacket(
            songTitle: currentSong.title,
            artistName: currentSong.artistName,
            artworkData: nil, // Artwork data transfer deferred to avoid large payloads
            isPlaying: isPlaying,
            progress: playbackProgress,
            duration: duration,
            explanation: nil // Explanation comes in a later phase
        )

        manager.sendNowPlaying(packet)
    }

    deinit {
        progressTimer?.invalidate()
    }

    // MARK: - Bindings

    private func setupBindings() {
        // Observe now playing changes
        musicService.nowPlayingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entry in
                self?.handleNowPlayingChange(entry)
            }
            .store(in: &cancellables)

        // Observe playback status changes
        musicService.playbackStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handlePlaybackStatusChange(status)
            }
            .store(in: &cancellables)
    }

    // MARK: - State Handlers

    private func handleNowPlayingChange(_ entry: MusicPlayer.Queue.Entry?) {
        guard let entry = entry else {
            currentSong = .placeholder
            duration = 0
            currentTime = 0
            playbackProgress = 0
            logDebug("Now playing cleared", category: .ui)
            return
        }

        let title = entry.title
        let subtitle = entry.subtitle ?? "--"

        // Extract artwork from the entry's item
        var artwork: MusicKit.Artwork?
        if case .song(let song) = entry.item {
            artwork = song.artwork
            duration = song.duration ?? 0
        } else {
            duration = 0
        }

        currentSong = SongDisplayInfo(
            title: title,
            artistName: subtitle,
            albumTitle: "",
            artwork: artwork,
            duration: duration
        )

        logDebug("Now playing: \(title) by \(subtitle)", category: .ui)

        // Sync to Watch
        sendNowPlayingToWatch()
    }

    private func handlePlaybackStatusChange(_ status: MusicPlayer.PlaybackStatus) {
        let wasPlaying = isPlaying
        isPlaying = (status == .playing)

        if wasPlaying != isPlaying {
            logDebug("Playback state changed: \(isPlaying ? "playing" : "paused/stopped")", category: .ui)

            // Sync play/pause state to Watch
            sendNowPlayingToWatch()
        }
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func updateProgress() {
        let time = musicService.currentPlaybackTime
        currentTime = time

        if duration > 0 {
            playbackProgress = time / duration
        } else {
            playbackProgress = 0
        }
    }

    // MARK: - Playback Actions

    /// Toggles between play and pause.
    func togglePlayPause() {
        Task {
            do {
                if isPlaying {
                    musicService.pause()
                } else {
                    try await musicService.resume()
                }
            } catch {
                logError("Toggle play/pause failed", error: error, category: .musicKit)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Skips to the next track.
    func skip() {
        Task {
            do {
                eventLogger?.logPlaybackEnd(wasSkipped: true, skipReason: "manual_skip", currentHeartRate: nil, currentHRV: nil)
                try await musicService.skipToNext()
            } catch {
                logError("Skip failed", error: error, category: .musicKit)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Skips to the previous track.
    func previous() {
        Task {
            do {
                eventLogger?.logPlaybackEnd(wasSkipped: true, skipReason: "manual_previous", currentHeartRate: nil, currentHRV: nil)
                try await musicService.skipToPrevious()
            } catch {
                logError("Previous failed", error: error, category: .musicKit)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Seeks to a specific progress position (0.0 to 1.0).
    func seek(to progress: Double) {
        guard duration > 0 else { return }
        let targetTime = progress * duration
        ApplicationMusicPlayer.shared.playbackTime = targetTime
        currentTime = targetTime
        playbackProgress = progress
        logDebug("Seeked to \(String(format: "%.1f", targetTime))s", category: .musicKit)
    }

    // MARK: - Formatting Helpers

    /// Formats a time interval as "m:ss".
    static func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
