//
//  PlaylistBrowserView.swift
//  Resonance
//
//  Displays the user's Apple Music playlists in a scrollable list.
//  Supports pull-to-refresh and playlist selection for playback.
//

import SwiftUI
import MusicKit

// MARK: - Playlist Browser View

struct PlaylistBrowserView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: PlaylistViewModel

    /// Callback invoked when a playlist is selected (used by parent to switch tabs).
    var onPlaylistSelected: ((PlaylistDisplayInfo) -> Void)?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.playlists.isEmpty {
                    loadingView
                } else if viewModel.playlists.isEmpty {
                    emptyStateView
                } else {
                    playlistList
                }
            }
            .navigationTitle("Your Playlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.fetchPlaylists() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: showErrorBinding) {
                Button("Retry") { viewModel.fetchPlaylists() }
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                if viewModel.playlists.isEmpty {
                    viewModel.fetchPlaylists()
                }
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
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading Playlists...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Playlists Found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Create playlists in Apple Music\nand they will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                viewModel.fetchPlaylists()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Playlist List

    private var playlistList: some View {
        List {
            Section {
                ForEach(viewModel.playlists) { playlistInfo in
                    PlaylistRow(
                        playlistInfo: playlistInfo,
                        isActive: viewModel.activePlaylistName == playlistInfo.name
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectPlaylist(playlistInfo)
                        onPlaylistSelected?(playlistInfo)
                    }
                }
            } header: {
                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Updating...")
                            .font(.caption)
                    }
                } else {
                    Text("\(viewModel.playlists.count) playlists")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.fetchPlaylists()
            // Wait briefly to allow the fetch to start
            try? await Task.sleep(nanoseconds: 500_000_000)
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
                    .foregroundStyle(.blue)
                    .font(.subheadline)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Artwork

    @ViewBuilder
    private var playlistArtwork: some View {
        if let artwork = playlistInfo.artwork {
            ArtworkImage(artwork, width: UIConstants.ArtworkSize.small)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 6))
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
