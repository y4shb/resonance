//
//  NowPlayingViewModel.swift
//  Resonance
//
//  ViewModel for the Now Playing screen. Wraps MusicKitService to provide
//  published playback state for the UI, including progress tracking via a timer.
//

import Foundation
import Combine
import CoreData
import MusicKit
import UIKit

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

    /// Decision engine for AI song selection. Set externally after init.
    var decisionEngine: DecisionEngine?

    /// Learning store for real-time song effect updates. Set externally after init.
    var learningStore: LearningStore?

    /// Real-time guard adjuster for biometric-aware filtering. Set externally after init.
    var guardAdjuster: RealTimeGuardAdjuster?

    /// State engine for current user state. Set externally after init.
    var stateEngine: StateEngine?

    /// The current AI explanation for why this song was selected (nil if manually chosen).
    @Published var currentExplanation: String?

    /// Whether the DJ should auto-select the next song when the current one ends.
    var aiAutoAdvanceEnabled: Bool = true

    /// Guards against triggering auto-advance more than once per song.
    private var hasTriggeredAutoAdvance: Bool = false

    /// Guards against auto-advance triggering during a user seek operation.
    private var isSeeking: Bool = false

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

        // Watch -> Phone: handle crown adjustments from Watch
        manager.crownAdjustments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] adjustment in
                self?.stateEngine?.applyCrownAdjustment(adjustment)
            }
            .store(in: &cancellables)

        // Phone -> Watch: resend current state when Watch becomes reachable
        manager.$watchIsReachable
            .removeDuplicates()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.sendNowPlayingToWatch()
            }
            .store(in: &cancellables)

        // Phone -> Watch: respond to Watch's explicit request for NowPlaying
        manager.nowPlayingRequests
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.sendNowPlayingToWatch()
            }
            .store(in: &cancellables)
    }

    /// Connects the LearningStore for real-time feedback loop.
    func connectLearningStore(_ store: LearningStore, eventLogger: EventLogger) {
        self.learningStore = store

        // Subscribe to completed playback events
        eventLogger.playbackEndEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak store] eventObjectID in
                store?.processPlaybackEvent(eventObjectID: eventObjectID)
            }
            .store(in: &cancellables)

        logInfo("LearningStore connected to NowPlayingViewModel", category: .stateEngine)
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

    /// Cached artwork data for Watch transfer (avoids re-fetching on play/pause).
    private var cachedWatchArtworkData: Data?

    /// Builds a NowPlayingPacket from current state and sends it to Watch.
    private func sendNowPlayingToWatch() {
        guard let manager = watchConnectivityManager else { return }

        let artwork = currentSong.artwork
        let songTitle = currentSong.title
        let artistName = currentSong.artistName
        let playing = isPlaying
        let progress = playbackProgress
        let dur = duration
        let explanation = currentExplanation
        let emoji = (stateEngine?.currentState.context ?? .unknown).emoji

        Task {
            // Use cached artwork if available, otherwise fetch and cache
            let artworkData: Data?
            if let cached = cachedWatchArtworkData {
                artworkData = cached
            } else {
                artworkData = await fetchArtworkData(for: artwork)
                cachedWatchArtworkData = artworkData
            }

            let packet = NowPlayingPacket(
                songTitle: songTitle,
                artistName: artistName,
                artworkData: artworkData,
                isPlaying: playing,
                progress: progress,
                duration: dur,
                explanation: explanation
            )

            manager.sendNowPlaying(packet)

            // Also send complication data for watch face updates
            let complicationData = ComplicationData(
                songTitle: songTitle,
                artistName: artistName,
                stateEmoji: emoji,
                heartRate: nil,
                isPlaying: playing,
                timestamp: Date()
            )
            manager.updateComplication(complicationData)
        }
    }

    /// Fetches and compresses artwork into a small JPEG for Watch transfer.
    private func fetchArtworkData(for artwork: MusicKit.Artwork?) async -> Data? {
        guard let artwork = artwork,
              let url = artwork.url(width: 160, height: 160) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            return image.jpegData(compressionQuality: 0.6)
        } catch {
            logDebug("Artwork fetch for Watch failed: \(error.localizedDescription)", category: .watchConnectivity)
            return nil
        }
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
        // Reset auto-advance flag for the new song
        hasTriggeredAutoAdvance = false
        // Clear cached artwork so the new song's artwork gets fetched
        cachedWatchArtworkData = nil
        // Clear stale explanation from the previous song
        currentExplanation = nil

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

        // Update iOS widgets
        WidgetDataStore.updateNowPlaying(
            title: title,
            artist: subtitle,
            isPlaying: isPlaying,
            progress: playbackProgress,
            duration: duration,
            explanation: currentExplanation
        )

        // Sync to Watch
        sendNowPlayingToWatch()
    }

    private func handlePlaybackStatusChange(_ status: MusicPlayer.PlaybackStatus) {
        let wasPlaying = isPlaying
        isPlaying = (status == .playing)

        if wasPlaying != isPlaying {
            logDebug("Playback state changed: \(isPlaying ? "playing" : "paused/stopped")", category: .ui)

            // Update iOS widgets with play/pause state change
            WidgetDataStore.updateNowPlaying(
                title: currentSong.title,
                artist: currentSong.artistName,
                isPlaying: isPlaying,
                progress: playbackProgress,
                duration: duration,
                explanation: currentExplanation
            )

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

        // Auto-advance: when the song is near its end, trigger AI selection for the next song
        if aiAutoAdvanceEnabled
            && !hasTriggeredAutoAdvance
            && !isSeeking
            && duration > 0
            && playbackProgress > 0.99
            && activePlaylistId != nil
            && decisionEngine != nil {
            hasTriggeredAutoAdvance = true

            // Log natural end of current playback event
            eventLogger?.logPlaybackEnd(wasSkipped: false, skipReason: nil, currentHeartRate: nil, currentHRV: nil)
            guardAdjuster?.recordFullListen()

            logInfo("Auto-advance triggered at \(String(format: "%.1f%%", playbackProgress * 100)) progress", category: .decisionEngine)
            requestAISelection()
        }
    }

    // MARK: - Playback Actions

    /// Toggles between play and pause.
    func togglePlayPause() {
        errorMessage = nil
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
        errorMessage = nil
        hasTriggeredAutoAdvance = true  // Prevent auto-advance from also firing
        Task {
            do {
                try await musicService.skipToNext()
                // Log after successful skip — if skip fails, the current song is still playing
                eventLogger?.logPlaybackEnd(wasSkipped: true, skipReason: "manual_skip", currentHeartRate: nil, currentHRV: nil)
                guardAdjuster?.recordSkip()
            } catch {
                logError("Skip failed", error: error, category: .musicKit)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Skips to the previous track.
    func previous() {
        errorMessage = nil
        hasTriggeredAutoAdvance = true  // Prevent auto-advance from also firing
        Task {
            do {
                try await musicService.skipToPrevious()
                // Log after successful previous — if it fails, the current song is still playing
                eventLogger?.logPlaybackEnd(wasSkipped: true, skipReason: "manual_previous", currentHeartRate: nil, currentHRV: nil)
                guardAdjuster?.recordSkip()
            } catch {
                logError("Previous failed", error: error, category: .musicKit)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Marks the start of a user seek operation (prevents auto-advance during seek).
    func seekStarted() {
        isSeeking = true
    }

    /// Seeks to a specific progress position (0.0 to 1.0).
    func seek(to progress: Double) {
        errorMessage = nil
        isSeeking = false
        guard duration > 0 else { return }
        let targetTime = progress * duration
        ApplicationMusicPlayer.shared.playbackTime = targetTime
        currentTime = targetTime
        playbackProgress = progress
        logDebug("Seeked to \(String(format: "%.1f", targetTime))s", category: .musicKit)
    }

    // MARK: - AI Song Selection

    /// The Core Data ID of the active playlist (set when a playlist is selected).
    var activePlaylistId: UUID?

    /// Asks the DecisionEngine to select the next song based on current state.
    /// Called automatically when a song ends, or manually by the user.
    func requestAISelection() {
        guard let engine = decisionEngine,
              let state = stateEngine?.currentState,
              let playlistId = activePlaylistId,
              let playlistName = activePlaylistName else {
            logDebug("AI selection unavailable: missing engine, state, or playlist", category: .decisionEngine)
            return
        }

        Task {
            guard let result = await engine.selectNextSong(
                playlistId: playlistId,
                playlistName: playlistName,
                stateVector: state
            ) else {
                logWarning("DecisionEngine returned no result", category: .decisionEngine)
                return
            }

            // Play the selected song
            await playSongById(result.songId)

            // Update explanation
            currentExplanation = result.explanation.full

            // Log the playback start with AI selection context
            let context = PersistenceController.shared.viewContext
            let fetchRequest = NSFetchRequest<Song>(entityName: "Song")
            fetchRequest.predicate = NSPredicate(format: "id == %@", result.songId as CVarArg)
            fetchRequest.fetchLimit = 1
            if let song = try? context.fetch(fetchRequest).first {
                eventLogger?.logPlaybackStart(
                    songAppleMusicId: song.appleMusicId ?? "",
                    wasAISelected: true,
                    selectionScore: result.score.finalScore,
                    selectionReason: result.explanation.short,
                    currentHeartRate: nil,
                    currentHRV: nil
                )
            }

            // Sync explanation to Watch
            sendNowPlayingToWatch()

            logInfo(
                "AI selected: '\(result.score.songTitle)' — \(result.explanation.short)",
                category: .decisionEngine
            )
        }
    }

    /// Plays a song from its Core Data UUID by looking up its Apple Music ID.
    private func playSongById(_ songId: UUID) async {
        let context = PersistenceController.shared.viewContext
        let fetchRequest = NSFetchRequest<Song>(entityName: "Song")
        fetchRequest.predicate = NSPredicate(format: "id == %@", songId as CVarArg)
        fetchRequest.fetchLimit = 1

        guard let song = try? context.fetch(fetchRequest).first,
              let appleMusicId = song.appleMusicId else {
            logWarning("Could not resolve song from UUID for playback", category: .decisionEngine)
            return
        }

        do {
            // Songs are synced from the user's library, so their IDs are library-
            // scoped identifiers.  Use MusicLibraryRequest (which queries the local
            // library) instead of MusicCatalogResourceRequest (which queries the
            // Apple Music catalog and does not recognise library IDs).
            var request = MusicLibraryRequest<MusicKit.Song>()
            request.filter(matching: \.id, equalTo: MusicItemID(rawValue: appleMusicId))
            let response = try await request.response()

            guard let mkSong = response.items.first else {
                logWarning("MusicKit song not found in library for ID '\(appleMusicId)'", category: .decisionEngine)
                errorMessage = "Song not found in your Apple Music library"
                return
            }

            try await musicService.play(song: mkSong)
        } catch {
            logError("Failed to play AI-selected song", error: error, category: .decisionEngine)
            errorMessage = "Failed to play selected song: \(error.localizedDescription)"
        }
    }

}
