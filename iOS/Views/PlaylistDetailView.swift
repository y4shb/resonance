//
//  PlaylistDetailView.swift
//  Resonance
//
//  Displays the songs within a playlist. Tapping a playlist in
//  PlaylistBrowserView navigates here instead of auto-playing.
//  Users can browse songs, search within the playlist, and choose
//  which song to play or play all / shuffle.
//

import SwiftUI
import MusicKit

// MARK: - Song List Item

/// Lightweight wrapper around MusicKit.Song for use in SwiftUI lists.
/// Provides stable identity and value-based equality without exposing
/// the full MusicKit.Song comparison surface.
struct SongListItem: Identifiable, Equatable {
    let id: MusicItemID
    let song: MusicKit.Song
    let trackNumber: Int

    static func == (lhs: SongListItem, rhs: SongListItem) -> Bool {
        lhs.id == rhs.id && lhs.trackNumber == rhs.trackNumber
    }
}

// MARK: - Playlist Detail View

struct PlaylistDetailView: View {
    // MARK: - Properties

    let playlistInfo: PlaylistDisplayInfo
    @Bindable var viewModel: PlaylistViewModel

    /// Callback invoked after playback starts (used by parent to switch tabs).
    var onPlaylistSelected: ((PlaylistDisplayInfo) -> Void)?

    // MARK: - State

    @State private var songs: [SongListItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    /// Filtered songs based on the current search text.
    private var filteredSongs: [SongListItem] {
        if searchText.isEmpty {
            return songs
        }
        let term = searchText.lowercased()
        return songs.filter { item in
            item.song.title.lowercased().contains(term)
            || item.song.artistName.lowercased().contains(term)
            || (item.song.albumTitle ?? "").lowercased().contains(term)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let errorMessage {
                errorView(message: errorMessage)
            } else if songs.isEmpty {
                emptyStateView
            } else {
                songList
            }
        }
        .navigationTitle(playlistInfo.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search songs")
        .task {
            await loadSongs()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading songs...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to Load Songs", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                self.errorMessage = nil
                isLoading = true
                Task { await loadSongs() }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Songs",
            systemImage: "music.note",
            description: Text("This playlist doesn't contain any songs.")
        )
    }

    // MARK: - 3D Cassette Carousel

    /// Songs displayed as a 3D vertical carousel of cassette tapes.
    /// Center cassette is front-facing; above/below tilt away in perspective.
    private var songList: some View {
        VStack(spacing: 0) {
            // Header with playlist cassette + action buttons
            cassettePlaylistHeader
                .padding(.bottom, 8)

            // Song count
            HStack {
                Text("\(filteredSongs.count) \(filteredSongs.count == 1 ? "song" : "songs")")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

            // 3D carousel
            if !searchText.isEmpty && filteredSongs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                cassetteCarousel
            }
        }
    }

    // MARK: - Playlist Header (Cassette Style)

    private var cassettePlaylistHeader: some View {
        VStack(spacing: 14) {
            // Playlist shown as a large cassette
            MiniCassetteView(
                artwork: playlistInfo.artwork,
                title: playlistInfo.name,
                subtitle: "\(songs.count) songs",
                width: 220
            )
            .rotation3DEffect(.degrees(5), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 6)
            .accessibilityLabel("Playlist: \(playlistInfo.name)")

            // Playlist description
            if let description = playlistInfo.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 40)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    playAll(shuffle: false)
                } label: {
                    Label("Play All", systemImage: "play.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(songs.isEmpty)
                .accessibilityLabel("Play all songs")

                Button {
                    playAll(shuffle: true)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(songs.isEmpty)
                .accessibilityLabel("Shuffle all songs")
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Cassette Carousel

    /// 3D vertical carousel using .scrollTransition for GPU-composited
    /// transforms without GeometryReader layout side effects.
    /// phase.value: -1 (above) → 0 (center) → 1 (below)
    private var cassetteCarousel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(filteredSongs) { item in
                    MiniCassetteView(
                        artwork: item.song.artwork,
                        title: item.song.title,
                        subtitle: item.song.artistName,
                        width: 280
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                        content
                            .rotation3DEffect(
                                .degrees(phase.value * 40),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.35
                            )
                            .scaleEffect(max(0.7, 1 - abs(phase.value) * 0.3))
                            .opacity(max(0.3, 1 - abs(phase.value) * 0.5))
                    }
                    .onTapGesture { playSong(item.song) }
                    .accessibilityLabel("\(item.song.title) by \(item.song.artistName)")
                    .accessibilityHint("Tap to play")
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 60)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    // MARK: - Actions

    /// Loads songs from the playlist via MusicKitService.
    private func loadSongs() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedSongs = try await viewModel.musicService.fetchPlaylistSongs(
                for: playlistInfo.playlist
            )

            var items: [SongListItem] = []
            for (index, song) in fetchedSongs.enumerated() {
                items.append(SongListItem(
                    id: song.id,
                    song: song,
                    trackNumber: index + 1
                ))
            }

            songs = items
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "We couldn't load the songs for this playlist. Please check your connection and try again."
        }
    }

    /// Plays a single song and notifies the parent to switch tabs.
    private func playSong(_ song: MusicKit.Song) {
        viewModel.playSong(song, fromPlaylist: playlistInfo)
        onPlaylistSelected?(playlistInfo)
    }

    /// Plays all songs in the playlist, optionally shuffled.
    private func playAll(shuffle: Bool) {
        let allSongs = songs.map(\.song)
        viewModel.playAllSongs(allSongs, fromPlaylist: playlistInfo, shuffle: shuffle)
        onPlaylistSelected?(playlistInfo)
    }
}

// MARK: - Song Row

private struct SongRow: View {
    let item: SongListItem

    var body: some View {
        HStack(spacing: 12) {
            // Track number
            Text("\(item.trackNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
                .monospacedDigit()

            // Song artwork
            songArtwork
                .frame(width: 44, height: 44)
                .cornerRadius(4)

            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.song.title)
                    .font(.body)
                    .lineLimit(1)

                Text(item.song.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            if let duration = item.song.duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(item.song.title) by \(item.song.artistName)"
            + (item.song.duration.map { ", \(formatDuration($0))" } ?? "")
        )
        .accessibilityHint("Tap to play this song")
    }

    // MARK: - Artwork

    @ViewBuilder
    private var songArtwork: some View {
        if let artwork = item.song.artwork {
            ArtworkImage(artwork, width: 44, height: 44)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(.ultraThinMaterial)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                )
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Duration Formatting

/// Formats a time interval as mm:ss or h:mm:ss for display.
/// Returns "0:00" for zero or negative durations.
private func formatDuration(_ duration: TimeInterval) -> String {
    guard duration > 0 else { return "0:00" }
    let totalSeconds = Int(duration)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
}

// MARK: - Preview

// Preview requires a real MusicKit.Playlist which cannot be synthesized
// outside of MusicKit. Use the app's live playlist data for previewing.
