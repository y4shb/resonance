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

// MARK: - Playlist Display Info

/// Lightweight struct representing playlist metadata for the UI layer.
struct PlaylistDisplayInfo: Identifiable, Equatable {
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
}

// MARK: - Playlist View Model

@MainActor
final class PlaylistViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Array of playlists available to the user.
    @Published private(set) var playlists: [PlaylistDisplayInfo] = []

    /// Whether playlists are currently being fetched.
    @Published private(set) var isLoading: Bool = false

    /// Error message to display in the UI.
    @Published var errorMessage: String?

    /// The currently selected/active playlist name.
    @Published private(set) var activePlaylistName: String?

    /// Whether Apple Music authorization has been denied.
    @Published private(set) var isMusicAuthDenied: Bool = false

    // MARK: - Private Properties

    private let musicService: MusicKitService
    private weak var nowPlayingViewModel: NowPlayingViewModel?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(musicService: MusicKitService, nowPlayingViewModel: NowPlayingViewModel? = nil) {
        self.musicService = musicService
        self.nowPlayingViewModel = nowPlayingViewModel

        // Track authorization status changes
        musicService.authorizationStatusPublisher
            .receive(on: DispatchQueue.main)
            .map { $0 == .denied }
            .assign(to: &$isMusicAuthDenied)

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
    func fetchPlaylists() {
        guard !isLoading else {
            logDebug("Playlist fetch already in progress, skipping", category: .musicKit)
            return
        }

        isLoading = true
        errorMessage = nil

        logInfo("Fetching user playlists", category: .musicKit)

        Task {
            do {
                let musicPlaylists = try await musicService.fetchUserPlaylists()

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
            } catch is MusicKitServiceError where musicService.authorizationStatus == .denied {
                self.isLoading = false
                self.isMusicAuthDenied = true
                self.errorMessage = "Apple Music access is required. Please grant access in Settings."
                logError("Failed to fetch playlists: authorization denied", category: .musicKit)
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logError("Failed to fetch playlists", error: error, category: .musicKit)
            }
        }
    }

    /// Selects a playlist, sets it as the playback queue, and begins playing.
    func selectPlaylist(_ playlistInfo: PlaylistDisplayInfo) {
        logInfo("User selected playlist: \(playlistInfo.name)", category: .ui)

        activePlaylistName = playlistInfo.name
        nowPlayingViewModel?.activePlaylistName = playlistInfo.name

        // Reset the decision engine session for the new playlist
        nowPlayingViewModel?.decisionEngine?.resetSession()

        Task {
            do {
                try await musicService.setQueue(playlist: playlistInfo.playlist)
                logInfo("Queue set from playlist '\(playlistInfo.name)'", category: .musicKit)
            } catch {
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
}
