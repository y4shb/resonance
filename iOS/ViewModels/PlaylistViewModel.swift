//
//  PlaylistViewModel.swift
//  Resonance
//
//  ViewModel for the Playlist Browser. Fetches the user's Apple Music playlists
//  and handles playlist selection for playback.
//

import Foundation
import Combine
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

    // MARK: - Private Properties

    private let musicService: MusicKitService
    private weak var nowPlayingViewModel: NowPlayingViewModel?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(musicService: MusicKitService, nowPlayingViewModel: NowPlayingViewModel? = nil) {
        self.musicService = musicService
        self.nowPlayingViewModel = nowPlayingViewModel

        logDebug("PlaylistViewModel initializing", category: .ui)
    }

    // MARK: - Public Methods

    /// Links this view model to a NowPlayingViewModel for active playlist propagation.
    func linkNowPlaying(_ viewModel: NowPlayingViewModel) {
        self.nowPlayingViewModel = viewModel
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

                // Map MusicKit playlists to display info
                var displayPlaylists: [PlaylistDisplayInfo] = []
                for playlist in musicPlaylists {
                    // Attempt to get song count by loading tracks
                    var songCount: Int? = nil
                    if let detailedPlaylist = try? await playlist.with([.tracks]) {
                        songCount = detailedPlaylist.tracks?.count
                    }

                    let info = PlaylistDisplayInfo(
                        id: playlist.id,
                        name: playlist.name,
                        description: playlist.standardDescription,
                        artwork: playlist.artwork,
                        songCount: songCount,
                        playlist: playlist
                    )
                    displayPlaylists.append(info)
                }

                self.playlists = displayPlaylists
                self.isLoading = false

                logInfo("Loaded \(displayPlaylists.count) playlists for display", category: .ui)

                // Persist playlists to Core Data
                Task.detached(priority: .utility) {
                    let repo = PlaylistRepository()
                    try? await repo.syncPlaylists(from: musicPlaylists)
                }
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
                if let cdPlaylist = cdPlaylist {
                    let songRepo = SongRepository()
                    try? await songRepo.syncSongs(songCollection, for: cdPlaylist)
                }
            }
        }
    }
}
