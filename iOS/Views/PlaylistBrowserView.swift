//
//  PlaylistBrowserView.swift
//  Resonance
//
//  Displays the user's Apple Music playlists in a scrollable list.
//  Supports pull-to-refresh and playlist selection for playback.
//

import SwiftUI
import CoreData
import MusicKit

// MARK: - Playlist Browser View

struct PlaylistBrowserView: View {
    // MARK: - Properties

    @Bindable var viewModel: PlaylistViewModel

    /// Callback invoked when a playlist is selected (used by parent to switch tabs).
    var onPlaylistSelected: ((PlaylistDisplayInfo) -> Void)?

    // Haptic feedback trigger for playlist selection
    @State private var selectionTrigger = 0

    // Search text for filtering playlists
    @State private var searchText = ""

    // Navigation path for mood playlist detail
    @State private var selectedMoodPlaylist: MoodPlaylist?

    // Mood playlist song counts (loaded from Core Data)
    @State private var moodPlaylistCounts: [MoodPlaylist: Int] = [:]

    private let songRepository = SongRepository()

    /// Playlists filtered by the current search text.
    private var filteredPlaylists: [PlaylistDisplayInfo] {
        if searchText.isEmpty {
            return viewModel.playlists
        }
        return viewModel.playlists.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isMusicAuthDenied {
                    PermissionStatusView(
                        title: "Music Access Required",
                        message: "Resonance needs access to Apple Music to browse your playlists.",
                        systemImage: "music.note.list",
                        actionTitle: "Grant Access",
                        onAction: { viewModel.requestMusicAuthorization() }
                    )
                } else if viewModel.isLoading && viewModel.playlists.isEmpty {
                    loadingView
                } else if viewModel.playlists.isEmpty {
                    emptyStateView
                } else if !searchText.isEmpty && filteredPlaylists.isEmpty {
                    searchEmptyStateView
                } else {
                    playlistList
                }
            }
            .navigationTitle("Your Playlists")
            .searchable(text: $searchText, prompt: "Search playlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.fetchPlaylists() }) {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Refresh playlists")
                    .accessibilityHint("Reload your playlists from Apple Music")
                }
            }
            .alert("Error", isPresented: showErrorBinding) {
                Button("Retry") { viewModel.fetchPlaylists() }
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert(
                "Switch Playlist?",
                isPresented: Binding(
                    get: { viewModel.pendingPlaylistSwitch != nil },
                    set: { if !$0 { viewModel.cancelPlaylistSwitch() } }
                )
            ) {
                Button("Switch", role: .destructive) {
                    if let pending = viewModel.pendingPlaylistSwitch {
                        viewModel.confirmPlaylistSwitch()
                        onPlaylistSelected?(pending)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelPlaylistSwitch()
                }
            } message: {
                Text("Your current session will end. AI learning from this session will be saved.")
            }
            .onAppear {
                if viewModel.playlists.isEmpty {
                    viewModel.fetchPlaylists()
                }
                loadMoodPlaylistCounts()
            }
            .navigationDestination(item: $selectedMoodPlaylist) { moodPlaylist in
                MoodDetailView(
                    title: moodPlaylist.displayName,
                    songs: fetchSongs(for: moodPlaylist),
                    accentColor: moodPlaylistAccentColor(moodPlaylist)
                )
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

    // MARK: - Loading View

    private var loadingView: some View {
        TimedSkeletonView(message: "Loading your playlists...") {
            SkeletonPlaylistCard()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Playlists Found",
            systemImage: "music.note.list",
            description: Text("Create playlists in Apple Music, then pull to refresh.")
        )
    }

    // MARK: - Search Empty State View

    private var searchEmptyStateView: some View {
        ContentUnavailableView.search(text: searchText)
    }

    // MARK: - Mood Playlist Helpers

    /// Loads song counts for each mood playlist from Core Data.
    private func loadMoodPlaylistCounts() {
        let context = PersistenceController.shared.viewContext
        var counts: [MoodPlaylist: Int] = [:]

        for moodPlaylist in MoodPlaylist.allCases {
            let request = NSFetchRequest<Song>(entityName: "Song")
            request.predicate = moodPlaylist.predicate
            let count = (try? context.count(for: request)) ?? 0
            counts[moodPlaylist] = count
        }

        moodPlaylistCounts = counts
    }

    /// Fetches songs matching a mood playlist's predicate.
    private func fetchSongs(for moodPlaylist: MoodPlaylist) -> [Song] {
        let context = PersistenceController.shared.viewContext
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = moodPlaylist.predicate
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    /// Maps a mood playlist's accent color string to a SwiftUI Color.
    private func moodPlaylistAccentColor(_ moodPlaylist: MoodPlaylist) -> Color {
        switch moodPlaylist.accentColor {
        case "teal":   return .teal
        case "blue":   return .blue
        case "red":    return .red
        case "yellow": return .yellow
        case "purple": return .purple
        case "cyan":   return .cyan
        default:       return .blue
        }
    }

    // MARK: - Playlist List

    private var playlistList: some View {
        List {
            // MARK: - Resonance Mixes

            Section {
                ForEach(MoodPlaylist.allCases) { moodPlaylist in
                    MoodPlaylistRow(
                        playlist: moodPlaylist,
                        songCount: moodPlaylistCounts[moodPlaylist] ?? 0
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMoodPlaylist = moodPlaylist
                    }
                }
            } header: {
                Label("Resonance Mixes", systemImage: "brain.head.profile")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            // MARK: - User Playlists

            Section {
                ForEach(filteredPlaylists) { playlistInfo in
                    NavigationLink(value: playlistInfo) {
                        PlaylistRow(
                            playlistInfo: playlistInfo,
                            isActive: viewModel.activePlaylistName == playlistInfo.name
                        )
                    }
                    .sensoryFeedback(.selection, trigger: selectionTrigger)
                }
            } header: {
                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        SkeletonShape(width: 12, height: 12, cornerRadius: 6)
                            .shimmer()
                        Text("Updating...")
                            .font(.caption)
                    }
                } else {
                    Text("\(filteredPlaylists.count) playlists")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: PlaylistDisplayInfo.self) { playlistInfo in
            PlaylistDetailView(
                playlistInfo: playlistInfo,
                viewModel: viewModel,
                onPlaylistSelected: onPlaylistSelected
            )
        }
        .refreshable {
            await viewModel.refreshPlaylists()
        }
    }
}

// MARK: - Playlist Row

private struct PlaylistRow: View {
    let playlistInfo: PlaylistDisplayInfo
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Playlist artwork
            playlistArtwork
                .frame(width: UIConstants.ArtworkSize.small, height: UIConstants.ArtworkSize.small)
                .cornerRadius(6)

            // Playlist info
            VStack(alignment: .leading, spacing: 3) {
                Text(playlistInfo.name)
                    .font(.body)
                    .fontWeight(isActive ? .semibold : .regular)
                    .lineLimit(1)

                if let count = playlistInfo.songCount {
                    Text("\(count) \(count == 1 ? "song" : "songs")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Playlist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Active indicator
            if isActive {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(ResonanceColors.accent)
                    .font(.subheadline)
                    .shadow(color: ResonanceColors.accent.opacity(0.4), radius: 4)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(playlistInfo.name)"
            + (playlistInfo.songCount.map { ", \($0) \($0 == 1 ? "song" : "songs")" } ?? "")
            + (isActive ? ", currently playing" : "")
        )
        .accessibilityHint(isActive ? "Currently active playlist" : "Tap to view songs")
    }

    // MARK: - Artwork

    @ViewBuilder
    private var playlistArtwork: some View {
        if let artwork = playlistInfo.artwork {
            // Request thumbnail-sized artwork to avoid loading full-resolution images
            ArtworkImage(artwork, width: UIConstants.ArtworkSize.small, height: UIConstants.ArtworkSize.small)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.clear)
                .glassEffect(.regular)
                .overlay(
                    Image(systemName: "music.note.list")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                )
        }
    }
}

// MARK: - Preview

#Preview {
    PlaylistBrowserView(
        viewModel: PlaylistViewModel(musicService: MusicKitService())
    )
}
