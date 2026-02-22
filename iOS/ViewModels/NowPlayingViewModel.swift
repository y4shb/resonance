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
            explanation: currentExplanation
        )

        manager.sendNowPlaying(packet)

        // Also send complication data for watch face updates
        let complicationData = ComplicationData(
            songTitle: currentSong.title,
            artistName: currentSong.artistName,
            stateEmoji: stateEmoji(for: stateEngine?.currentState),
            heartRate: nil,
            isPlaying: isPlaying,
            timestamp: Date()
        )
        manager.updateComplication(complicationData)
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

        // Auto-advance: when the song is near its end, trigger AI selection for the next song
        if aiAutoAdvanceEnabled
            && !hasTriggeredAutoAdvance
            && duration > 0
            && playbackProgress > 0.95
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
        hasTriggeredAutoAdvance = true  // Prevent auto-advance from also firing
        Task {
            do {
                eventLogger?.logPlaybackEnd(wasSkipped: true, skipReason: "manual_skip", currentHeartRate: nil, currentHRV: nil)
                guardAdjuster?.recordSkip()
                try await musicService.skipToNext()
            } catch {
                logError("Skip failed", error: error, category: .musicKit)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Skips to the previous track.
    func previous() {
        hasTriggeredAutoAdvance = true  // Prevent auto-advance from also firing
        Task {
            do {
                eventLogger?.logPlaybackEnd(wasSkipped: true, skipReason: "manual_previous", currentHeartRate: nil, currentHRV: nil)
                guardAdjuster?.recordSkip()
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
            // Fetch the MusicKit Song by Apple Music ID
            var request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(rawValue: appleMusicId))
            request.limit = 1
            let response = try await request.response()

            guard let mkSong = response.items.first else {
                logWarning("MusicKit song not found for ID '\(appleMusicId)'", category: .decisionEngine)
                return
            }

            try await musicService.play(song: mkSong)
        } catch {
            logError("Failed to play AI-selected song", error: error, category: .decisionEngine)
            errorMessage = "Failed to play selected song"
        }
    }

    // MARK: - Formatting Helpers

    /// Formats a time interval as "m:ss".
    static func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Complication Helpers

    /// Maps the current state context to an emoji for complications.
    private func stateEmoji(for state: StateVector?) -> String {
        guard let state = state else { return "\u{1F3B5}" }
        switch state.context {
        case .workout: return "\u{1F3C3}"
        case .postWorkout: return "\u{1F4AA}"
        case .deepWork: return "\u{1F9E0}"
        case .work: return "\u{1F4BC}"
        case .commute: return "\u{1F697}"
        case .preSleep: return "\u{1F319}"
        case .morning: return "\u{2600}\u{FE0F}"
        case .relaxation: return "\u{1F9D8}"
        default: return "\u{1F3B5}"
        }
    }
}
