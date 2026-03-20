//
//  PlaylistViewModel.swift
//  Resonance
//
//  ViewModel for the Playlist Browser. Fetches the user's Apple Music playlists
//  and handles playlist selection for playback.
//

import Foundation
import Combine
import CoreData
import MusicKit
import Observation

// MARK: - Playlist Display Info

/// Lightweight struct representing playlist metadata for the UI layer.
struct PlaylistDisplayInfo: Identifiable, Equatable, Hashable {
    let id: MusicItemID
    let name: String
    let description: String?
    let artwork: MusicKit.Artwork?
    let songCount: Int?

    /// The underlying MusicKit playlist. Not compared in Equatable.
    let playlist: MusicKit.Playlist

    static func == (lhs: PlaylistDisplayInfo, rhs: PlaylistDisplayInfo) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.songCount == rhs.songCount
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Playlist View Model

/// @Observable replaces ObservableObject for per-property tracking.
/// Playlist list updates don't cascade redraws to unrelated views.
@MainActor
@Observable
final class PlaylistViewModel {
    // MARK: - Observed Properties

    /// Array of playlists available to the user.
    private(set) var playlists: [PlaylistDisplayInfo] = []

    /// Whether playlists are currently being fetched.
    private(set) var isLoading = false

    /// Error message to display in the UI.
    var errorMessage: String?

    /// The currently selected/active playlist name.
    private(set) var activePlaylistName: String?

    /// Whether Apple Music authorization has been denied.
    private(set) var isMusicAuthDenied = false

    // MARK: - Private Properties

    let musicService: MusicKitService
    private weak var nowPlayingViewModel: NowPlayingViewModel?
    private var cancellables = Set<AnyCancellable>()

    /// Tracks the current in-flight fetch or select operation.
    /// Cancelled before starting a new operation to prevent interleaving.
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization

    init(musicService: MusicKitService, nowPlayingViewModel: NowPlayingViewModel? = nil) {
        self.musicService = musicService
        self.nowPlayingViewModel = nowPlayingViewModel

        // Track authorization status changes
        musicService.authorizationStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isMusicAuthDenied = (status == .denied)
            }
            .store(in: &cancellables)

        logDebug("PlaylistViewModel initializing", category: .ui)
    }

    // MARK: - Public Methods

    /// Links this view model to a NowPlayingViewModel for active playlist propagation.
    func linkNowPlaying(_ viewModel: NowPlayingViewModel) {
        self.nowPlayingViewModel = viewModel
    }

    /// Requests Apple Music authorization and refreshes playlists on success.
    func requestMusicAuthorization() {
        Task {
            let status = await musicService.requestAuthorization()
            if status == .authorized {
                fetchPlaylists()
            }
        }
    }

    /// Fetches all playlists from the user's Apple Music library.
    /// Cancels any in-flight fetch or select operation before starting.
    func fetchPlaylists() {
        // Cancel any in-flight operation to prevent interleaving
        currentTask?.cancel()

        isLoading = true
        errorMessage = nil

        logInfo("Fetching user playlists", category: .musicKit)

        currentTask = Task {
            do {
                let musicPlaylists = try await musicService.fetchUserPlaylists()

                guard !Task.isCancelled else { return }

                // Show playlists immediately without song counts
                let displayPlaylists: [PlaylistDisplayInfo] = musicPlaylists.map { playlist in
                    PlaylistDisplayInfo(
                        id: playlist.id,
                        name: playlist.name,
                        description: playlist.standardDescription,
                        artwork: playlist.artwork,
                        songCount: nil,
                        playlist: playlist
                    )
                }

                self.playlists = displayPlaylists
                self.isLoading = false

                logInfo("Loaded \(displayPlaylists.count) playlists for display", category: .ui)

                // Persist playlists to Core Data
                Task.detached(priority: .utility) {
                    let repo = PlaylistRepository()
                    try? await repo.syncPlaylists(from: musicPlaylists)
                }

                // Load song counts concurrently and update UI as they arrive
                await withTaskGroup(of: (MusicItemID, Int?).self) { group in
                    for playlist in musicPlaylists {
                        group.addTask {
                            let count: Int? = if let detailed = try? await playlist.with([.tracks]) {
                                detailed.tracks?.count
                            } else {
                                nil
                            }
                            return (playlist.id, count)
                        }
                    }

                    for await (playlistId, songCount) in group {
                        guard !Task.isCancelled else { return }
                        if let index = self.playlists.firstIndex(where: { $0.id == playlistId }) {
                            let existing = self.playlists[index]
                            self.playlists[index] = PlaylistDisplayInfo(
                                id: existing.id,
                                name: existing.name,
                                description: existing.description,
                                artwork: existing.artwork,
                                songCount: songCount,
                                playlist: existing.playlist
                            )
                        }
                    }
                }

                logDebug("All playlist song counts loaded", category: .ui)
            } catch is CancellationError {
                logDebug("Playlist fetch cancelled", category: .musicKit)
            } catch is MusicKitServiceError where musicService.authorizationStatus == .denied {
                self.isLoading = false
                self.isMusicAuthDenied = true
                self.errorMessage = "Apple Music access is required. Please grant access in Settings."
                logError("Failed to fetch playlists: authorization denied", category: .musicKit)
            } catch {
                guard !Task.isCancelled else { return }
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logError("Failed to fetch playlists", error: error, category: .musicKit)
            }
        }
    }

    /// Async version of `fetchPlaylists()` for use with SwiftUI `.refreshable`.
    /// Awaits the completion of the fetch task so the refresh spinner dismisses naturally.
    func refreshPlaylists() async {
        fetchPlaylists()
        // Await the tracked task so .refreshable knows when loading finishes
        await currentTask?.value
    }

    /// Selects a playlist, sets it as the playback queue, and begins playing.
    /// Cancels any in-flight fetch or select operation before starting.
    func selectPlaylist(_ playlistInfo: PlaylistDisplayInfo) {
        // Cancel any in-flight operation to prevent interleaving with fetchPlaylists
        currentTask?.cancel()
        isLoading = false

        logInfo("User selected playlist: \(playlistInfo.name)", category: .ui)

        activePlaylistName = playlistInfo.name
        nowPlayingViewModel?.activePlaylistName = playlistInfo.name

        // Reset the decision engine session for the new playlist
        nowPlayingViewModel?.decisionEngine?.resetSession()

        currentTask = Task {
            do {
                try await musicService.setQueue(playlist: playlistInfo.playlist)
                guard !Task.isCancelled else { return }
                logInfo("Queue set from playlist '\(playlistInfo.name)'", category: .musicKit)
            } catch is CancellationError {
                logDebug("Playlist select cancelled", category: .musicKit)
            } catch {
                guard !Task.isCancelled else { return }
                // Queue load failed — clear the optimistically-set playlist name
                activePlaylistName = nil
                nowPlayingViewModel?.activePlaylistName = nil
                nowPlayingViewModel?.activePlaylistId = nil
                errorMessage = error.localizedDescription
                logError("Failed to set queue from playlist '\(playlistInfo.name)'", error: error, category: .musicKit)
            }
        }

        // Find Core Data playlist on main thread (viewContext is main-queue only)
        let playlistRepo = PlaylistRepository()
        let cdPlaylist = playlistRepo.findByAppleMusicId(playlistInfo.id.rawValue)

        // Set the active playlist ID for AI selection
        if let cdPlaylist = cdPlaylist, let playlistId = cdPlaylist.id {
            nowPlayingViewModel?.activePlaylistId = playlistId
        } else {
            // Core Data lookup failed — clear the stale playlist ID
            nowPlayingViewModel?.activePlaylistId = nil
            logWarning("Core Data lookup failed for playlist '\(playlistInfo.name)'; activePlaylistId cleared", category: .musicKit)
        }

        // Capture the thread-safe objectID on the main thread;
        // the NSManagedObject itself must NOT cross into Task.detached.
        let playlistObjectID = cdPlaylist?.objectID

        // Sync songs in background
        Task.detached(priority: .utility) {
            if let detailedPlaylist = try? await playlistInfo.playlist.with([.tracks]),
               let tracks = detailedPlaylist.tracks {
                // Convert Track items to Song items for Core Data sync
                var songs: [MusicKit.Song] = []
                for track in tracks {
                    switch track {
                    case .song(let song):
                        songs.append(song)
                    default:
                        break
                    }
                }
                let songCollection = MusicItemCollection(songs)
                if let playlistObjectID = playlistObjectID {
                    // Re-fetch the Playlist in a background context to
                    // respect Core Data thread confinement.
                    let bgContext = PersistenceController.shared.newBackgroundContext()
                    guard let bgPlaylist = try? bgContext.existingObject(with: playlistObjectID) as? Playlist else {
                        return
                    }
                    let songRepo = SongRepository()
                    try? await songRepo.syncSongs(songCollection, for: bgPlaylist)
                }
            }
        }
    }

    /// Plays a single song from within a playlist context.
    /// Sets the queue to the song and begins playback without disturbing
    /// the active playlist state.
    func playSong(_ song: MusicKit.Song, fromPlaylist playlistInfo: PlaylistDisplayInfo) {
        logInfo("Playing song '\(song.title)' from playlist '\(playlistInfo.name)'", category: .ui)

        activePlaylistName = playlistInfo.name
        nowPlayingViewModel?.activePlaylistName = playlistInfo.name

        // Look up the Core Data UUID for this playlist so AI auto-advance works
        let playlistRepo = PlaylistRepository()
        if let cdPlaylist = playlistRepo.findByAppleMusicId(playlistInfo.id.rawValue),
           let playlistUUID = cdPlaylist.id {
            nowPlayingViewModel?.activePlaylistId = playlistUUID
        }

        currentTask?.cancel()

        currentTask = Task {
            do {
                try await musicService.play(song: song)
                guard !Task.isCancelled else { return }
                logInfo("Now playing '\(song.title)' from '\(playlistInfo.name)'", category: .musicKit)
            } catch is CancellationError {
                logDebug("Song play cancelled", category: .musicKit)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                logError("Failed to play song '\(song.title)'", error: error, category: .musicKit)
            }
        }
    }

    /// Plays all songs from a playlist, optionally shuffled.
    /// Sets the queue to the full song list and begins playback.
    func playAllSongs(
        _ songs: [MusicKit.Song],
        fromPlaylist playlistInfo: PlaylistDisplayInfo,
        shuffle: Bool
    ) {
        guard !songs.isEmpty else {
            errorMessage = "No songs to play."
            return
        }

        logInfo(
            "Playing all \(songs.count) songs from '\(playlistInfo.name)'"
            + (shuffle ? " (shuffled)" : ""),
            category: .ui
        )

        activePlaylistName = playlistInfo.name
        nowPlayingViewModel?.activePlaylistName = playlistInfo.name
        nowPlayingViewModel?.decisionEngine?.resetSession()

        // Look up the Core Data UUID for this playlist so AI auto-advance works
        let playlistRepo = PlaylistRepository()
        if let cdPlaylist = playlistRepo.findByAppleMusicId(playlistInfo.id.rawValue),
           let playlistUUID = cdPlaylist.id {
            nowPlayingViewModel?.activePlaylistId = playlistUUID
        }

        // Set shuffle mode before queuing
        musicService.shuffleMode = shuffle ? .songs : .off

        currentTask?.cancel()

        currentTask = Task {
            do {
                try await musicService.setQueue(songs: songs)
                guard !Task.isCancelled else { return }
                logInfo("Queue set with \(songs.count) songs from '\(playlistInfo.name)'", category: .musicKit)
            } catch is CancellationError {
                logDebug("Play-all cancelled", category: .musicKit)
            } catch {
                guard !Task.isCancelled else { return }
                activePlaylistName = nil
                nowPlayingViewModel?.activePlaylistName = nil
                nowPlayingViewModel?.activePlaylistId = nil
                errorMessage = error.localizedDescription
                logError("Failed to play all songs from '\(playlistInfo.name)'", error: error, category: .musicKit)
            }
        }
    }
}
