//
//  MusicKitService.swift
//  Resonance
//
//  MusicKit service protocol and implementation for Apple Music playback and library access.
//  Provides authorization, library fetching, and playback control via ApplicationMusicPlayer.
//

import Foundation
import Combine
import MusicKit

// MARK: - MusicKit Service Protocol

/// Protocol defining the interface for MusicKit operations.
/// Uses MusicKit native types directly; Core Data mapping deferred to Phase 3.
public protocol MusicKitServiceProtocol: ObservableObject {
    // MARK: Authorization

    /// Requests MusicKit authorization from the user.
    func requestAuthorization() async -> MusicAuthorization.Status

    /// Current authorization status.
    var authorizationStatus: MusicAuthorization.Status { get }

    /// Publisher for authorization status changes.
    var authorizationStatusPublisher: AnyPublisher<MusicAuthorization.Status, Never> { get }

    // MARK: Library Access

    /// Fetches the user's playlists from their Apple Music library.
    func fetchUserPlaylists() async throws -> MusicItemCollection<MusicKit.Playlist>

    /// Fetches songs contained in a specific playlist.
    func fetchPlaylistSongs(for playlist: MusicKit.Playlist) async throws -> MusicItemCollection<MusicKit.Song>

    /// Fetches recently played items.
    func fetchRecentlyPlayed(limit: Int) async throws -> MusicItemCollection<MusicKit.RecentlyPlayedMusicItem>

    // MARK: Playback Control

    /// Begins playback of a specific song.
    func play(song: MusicKit.Song) async throws

    /// Pauses the current playback.
    func pause()

    /// Resumes playback.
    func resume() async throws

    /// Skips to the next track in the queue.
    func skipToNext() async throws

    /// Skips to the previous track in the queue.
    func skipToPrevious() async throws

    /// Sets the playback queue with an array of songs.
    func setQueue(songs: [MusicKit.Song]) async throws

    /// Sets the playback queue from a playlist and starts playing.
    func setQueue(playlist: MusicKit.Playlist) async throws

    // MARK: Playback State

    /// The currently playing song entry, if any.
    var nowPlayingEntry: MusicPlayer.Queue.Entry? { get }

    /// The current playback status.
    var playbackStatus: MusicPlayer.PlaybackStatus { get }

    /// The current playback time in seconds.
    var currentPlaybackTime: TimeInterval { get }

    // MARK: Publishers

    /// Publishes changes to the now-playing queue entry.
    var nowPlayingPublisher: AnyPublisher<MusicPlayer.Queue.Entry?, Never> { get }

    /// Publishes changes to the playback status.
    var playbackStatusPublisher: AnyPublisher<MusicPlayer.PlaybackStatus, Never> { get }
}

// MARK: - MusicKit Service Errors

/// Errors specific to the MusicKitService.
public enum MusicKitServiceError: LocalizedError {
    case notAuthorized
    case playbackFailed(underlying: Error)
    case queueEmpty
    case playlistLoadFailed(underlying: Error)
    case songsFetchFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "MusicKit authorization has not been granted. Please allow access to Apple Music in Settings."
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        case .queueEmpty:
            return "The playback queue is empty. Please select a playlist or song."
        case .playlistLoadFailed(let error):
            return "Failed to load playlists: \(error.localizedDescription)"
        case .songsFetchFailed(let error):
            return "Failed to fetch songs: \(error.localizedDescription)"
        }
    }
}

// MARK: - MusicKit Service Implementation

/// Concrete implementation of `MusicKitServiceProtocol` using `ApplicationMusicPlayer`.
public final class MusicKitService: MusicKitServiceProtocol {
    // MARK: - Published State

    @Published public private(set) var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published public private(set) var nowPlayingEntry: MusicPlayer.Queue.Entry?
    @Published public private(set) var playbackStatus: MusicPlayer.PlaybackStatus = .stopped

    // MARK: - Publishers

    public var authorizationStatusPublisher: AnyPublisher<MusicAuthorization.Status, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }

    public var nowPlayingPublisher: AnyPublisher<MusicPlayer.Queue.Entry?, Never> {
        $nowPlayingEntry.eraseToAnyPublisher()
    }

    public var playbackStatusPublisher: AnyPublisher<MusicPlayer.PlaybackStatus, Never> {
        $playbackStatus.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private let player = ApplicationMusicPlayer.shared
    private var cancellables = Set<AnyCancellable>()
    private var stateObservationTask: Task<Void, Never>?

    // MARK: - Computed Properties

    public var currentPlaybackTime: TimeInterval {
        player.playbackTime
    }

    // MARK: - Initialization

    public init() {
        logInfo("MusicKitService initializing", category: .musicKit)

        // Read the current authorization status synchronously
        authorizationStatus = MusicAuthorization.currentStatus

        // Observe player state changes
        observePlayerState()

        logInfo("MusicKitService initialized. Auth status: \(authorizationStatus)", category: .musicKit)
    }

    deinit {
        stateObservationTask?.cancel()
    }

    // MARK: - Authorization

    @discardableResult
    public func requestAuthorization() async -> MusicAuthorization.Status {
        logInfo("Requesting MusicKit authorization", category: .musicKit)

        let status = await MusicAuthorization.request()

        await MainActor.run {
            self.authorizationStatus = status
        }

        switch status {
        case .authorized:
            logInfo("MusicKit authorization granted", category: .musicKit)
        case .denied:
            logWarning("MusicKit authorization denied by user", category: .musicKit)
        case .restricted:
            logWarning("MusicKit authorization restricted", category: .musicKit)
        case .notDetermined:
            logDebug("MusicKit authorization not yet determined", category: .musicKit)
        @unknown default:
            logWarning("MusicKit authorization returned unknown status: \(status)", category: .musicKit)
        }

        return status
    }

    // MARK: - Library Access

    public func fetchUserPlaylists() async throws -> MusicItemCollection<MusicKit.Playlist> {
        guard authorizationStatus == .authorized else {
            logError("Cannot fetch playlists: not authorized", category: .musicKit)
            throw MusicKitServiceError.notAuthorized
        }

        logDebug("Fetching user playlists", category: .musicKit)

        do {
            var request = MusicLibraryRequest<MusicKit.Playlist>()
            request.limit = MusicKitConstants.maxPlaylistFetch
            let response = try await request.response()

            logInfo("Fetched \(response.items.count) playlists", category: .musicKit)
            return response.items
        } catch {
            logError("Failed to fetch playlists", error: error, category: .musicKit)
            throw MusicKitServiceError.playlistLoadFailed(underlying: error)
        }
    }

    public func fetchPlaylistSongs(for playlist: MusicKit.Playlist) async throws -> MusicItemCollection<MusicKit.Song> {
        guard authorizationStatus == .authorized else {
            logError("Cannot fetch playlist songs: not authorized", category: .musicKit)
            throw MusicKitServiceError.notAuthorized
        }

        logDebug("Fetching songs for playlist: \(playlist.name)", category: .musicKit)

        do {
            let detailedPlaylist = try await playlist.with([.tracks])
            var songs: [MusicKit.Song] = []

            if let tracks = detailedPlaylist.tracks {
                for track in tracks {
                    switch track {
                    case .song(let song):
                        songs.append(song)
                    default:
                        break
                    }
                }
            }

            logInfo("Fetched \(songs.count) songs from playlist '\(playlist.name)'", category: .musicKit)
            return MusicItemCollection(songs)
        } catch {
            logError("Failed to fetch songs for playlist '\(playlist.name)'", error: error, category: .musicKit)
            throw MusicKitServiceError.songsFetchFailed(underlying: error)
        }
    }

    public func fetchRecentlyPlayed(limit: Int) async throws -> MusicItemCollection<MusicKit.RecentlyPlayedMusicItem> {
        guard authorizationStatus == .authorized else {
            logError("Cannot fetch recently played: not authorized", category: .musicKit)
            throw MusicKitServiceError.notAuthorized
        }

        logDebug("Fetching recently played items (limit: \(limit))", category: .musicKit)

        do {
            var request = MusicRecentlyPlayedRequest<MusicKit.RecentlyPlayedMusicItem>()
            request.limit = limit
            let response = try await request.response()

            logInfo("Fetched \(response.items.count) recently played items", category: .musicKit)
            return response.items
        } catch {
            logError("Failed to fetch recently played", error: error, category: .musicKit)
            throw MusicKitServiceError.songsFetchFailed(underlying: error)
        }
    }

    // MARK: - Playback Control

    public func play(song: MusicKit.Song) async throws {
        guard authorizationStatus == .authorized else {
            throw MusicKitServiceError.notAuthorized
        }

        logInfo("Playing song: \(song.title) by \(song.artistName)", category: .musicKit)

        do {
            player.queue = [song]
            try await player.play()
        } catch {
            logError("Failed to play song '\(song.title)'", error: error, category: .musicKit)
            throw MusicKitServiceError.playbackFailed(underlying: error)
        }
    }

    public func pause() {
        logDebug("Pausing playback", category: .musicKit)
        player.pause()
    }

    public func resume() async throws {
        logDebug("Resuming playback", category: .musicKit)

        do {
            try await player.play()
        } catch {
            logError("Failed to resume playback", error: error, category: .musicKit)
            throw MusicKitServiceError.playbackFailed(underlying: error)
        }
    }

    public func skipToNext() async throws {
        logDebug("Skipping to next track", category: .musicKit)

        do {
            try await player.skipToNextEntry()
        } catch {
            logError("Failed to skip to next track", error: error, category: .musicKit)
            throw MusicKitServiceError.playbackFailed(underlying: error)
        }
    }

    public func skipToPrevious() async throws {
        logDebug("Skipping to previous track", category: .musicKit)

        do {
            try await player.skipToPreviousEntry()
        } catch {
            logError("Failed to skip to previous track", error: error, category: .musicKit)
            throw MusicKitServiceError.playbackFailed(underlying: error)
        }
    }

    public func setQueue(songs: [MusicKit.Song]) async throws {
        guard !songs.isEmpty else {
            logWarning("Attempted to set empty queue", category: .musicKit)
            throw MusicKitServiceError.queueEmpty
        }

        logInfo("Setting queue with \(songs.count) songs", category: .musicKit)

        do {
            player.queue = ApplicationMusicPlayer.Queue(for: songs)
            try await player.play()
        } catch {
            logError("Failed to set queue", error: error, category: .musicKit)
            throw MusicKitServiceError.playbackFailed(underlying: error)
        }
    }

    public func setQueue(playlist: MusicKit.Playlist) async throws {
        guard authorizationStatus == .authorized else {
            throw MusicKitServiceError.notAuthorized
        }

        logInfo("Setting queue from playlist: \(playlist.name)", category: .musicKit)

        do {
            player.queue = ApplicationMusicPlayer.Queue(for: [playlist])
            try await player.play()
        } catch {
            logError("Failed to set queue from playlist '\(playlist.name)'", error: error, category: .musicKit)
            throw MusicKitServiceError.playbackFailed(underlying: error)
        }
    }

    // MARK: - State Observation

    private func observePlayerState() {
        stateObservationTask = Task { [weak self] in
            guard let self = self else { return }

            logDebug("Starting player state observation", category: .musicKit)

            // Observe playback state using the player's objectWillChange
            for await _ in self.player.state.objectWillChange.values {
                guard !Task.isCancelled else { break }

                let newStatus = self.player.state.playbackStatus
                let newEntry = self.player.queue.currentEntry

                await MainActor.run {
                    if self.playbackStatus != newStatus {
                        self.playbackStatus = newStatus
                        logDebug("Playback status changed: \(newStatus)", category: .musicKit)
                    }

                    if self.nowPlayingEntry?.id != newEntry?.id {
                        self.nowPlayingEntry = newEntry
                        if let entry = newEntry {
                            logDebug("Now playing entry changed: \(entry.title)", category: .musicKit)
                        } else {
                            logDebug("Now playing entry cleared", category: .musicKit)
                        }
                    }
                }
            }
        }
    }
}
