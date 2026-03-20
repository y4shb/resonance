//
//  MoodDetailView.swift
//  Resonance
//
//  Displays songs belonging to a specific mood category or mood playlist.
//  Shows song artwork, title, and artist with tap-to-play support.
//

import SwiftUI
import CoreData

// MARK: - Mood Detail View

/// Lists songs filtered by a mood category or mood playlist predicate.
///
/// Displays song artwork, title, and artist with tap-to-play support.
/// Includes a search bar for filtering songs within the mood group.
struct MoodDetailView: View {

    // MARK: - Properties

    /// Title displayed in the navigation bar.
    let title: String

    /// Songs to display, pre-filtered by mood category or playlist predicate.
    let songs: [Song]

    /// Accent color for play button icons, matching the mood's theme.
    let accentColor: Color

    /// Callback invoked when the user taps a song to play it.
    var onSongSelected: ((Song) -> Void)?

    // MARK: - State

    @State private var searchText = ""

    private var filteredSongs: [Song] {
        if searchText.isEmpty {
            return songs
        }
        return songs.filter { song in
            let titleMatch = (song.title ?? "").localizedCaseInsensitiveContains(searchText)
            let artistMatch = (song.artistName ?? "").localizedCaseInsensitiveContains(searchText)
            return titleMatch || artistMatch
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if songs.isEmpty {
                emptyState
            } else if !searchText.isEmpty && filteredSongs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                songList
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Search songs")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Songs Yet",
            systemImage: "music.note",
            description: Text(
                "Songs will appear here once Resonance has analyzed your library's audio features."
            )
        )
    }

    // MARK: - Song List

    private var songList: some View {
        List {
            Section {
                ForEach(filteredSongs, id: \.objectID) { song in
                    SongRow(song: song, accentColor: accentColor)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSongSelected?(song)
                        }
                }
            } header: {
                Text("\(filteredSongs.count) \(filteredSongs.count == 1 ? "song" : "songs")")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Song Row

/// A single row displaying a song's artwork, title, and artist.
private struct SongRow: View {
    let song: Song
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            // Artwork
            songArtwork
                .frame(width: UIConstants.ArtworkSize.small, height: UIConstants.ArtworkSize.small)
                .cornerRadius(6)

            // Song info
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title ?? "Unknown Title")
                    .font(.body)
                    .lineLimit(1)

                Text(song.artistName ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            if song.durationSeconds > 0 {
                Text(formatDuration(song.durationSeconds))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Image(systemName: "play.circle")
                .foregroundStyle(accentColor)
                .font(.title3)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(song.title ?? "Unknown"), by \(song.artistName ?? "Unknown")"
            + (song.durationSeconds > 0 ? ", \(formatDuration(song.durationSeconds))" : "")
        )
        .accessibilityHint("Tap to play this song")
    }

    // MARK: - Artwork

    @ViewBuilder
    private var songArtwork: some View {
        if let urlString = song.artworkURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    artworkPlaceholder
                }
            }
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.ultraThinMaterial)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            )
            .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0:00" }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
