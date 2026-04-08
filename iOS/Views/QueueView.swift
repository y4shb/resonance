//
//  QueueView.swift
//  Resonance
//
//  Displays the upcoming songs in the playback queue (up-next view).
//  Presented as a sheet from NowPlayingView via the queue button.
//

import SwiftUI
import MusicKit

// MARK: - Queue View

struct QueueView: View {
    @Bindable var viewModel: NowPlayingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                let entries = viewModel.queueEntries
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Upcoming Songs",
                        systemImage: "music.note.list",
                        description: Text("Songs will appear here when a playlist is playing.")
                    )
                } else {
                    List {
                        Section {
                            // Now Playing header
                            nowPlayingRow
                        } header: {
                            Text("Now Playing")
                        }

                        Section {
                            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                                queueEntryRow(entry: entry, index: index + 1)
                            }
                        } header: {
                            Text("Up Next (\(entries.count) songs)")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Now Playing Row

    private var nowPlayingRow: some View {
        HStack(spacing: 12) {
            // Artwork thumbnail
            if let artwork = viewModel.currentSong.artwork {
                ArtworkImage(artwork, width: 44, height: 44)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentSong.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(viewModel.currentSong.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Now playing indicator
            Image(systemName: viewModel.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                .font(.caption)
                .foregroundStyle(ResonanceColors.accent)
                .symbolEffect(.variableColor.iterative, isActive: viewModel.isPlaying)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(viewModel.currentSong.title) by \(viewModel.currentSong.artistName)")
    }

    // MARK: - Queue Entry Row

    private func queueEntryRow(entry: MusicPlayer.Queue.Entry, index: Int) -> some View {
        HStack(spacing: 12) {
            // Index number
            Text("\(index)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 20, alignment: .trailing)
                .monospacedDigit()

            // Artwork
            if let artwork = entryArtwork(entry) {
                ArtworkImage(artwork, width: 40, height: 40)
                    .cornerRadius(5)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
            }

            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(entry.subtitle ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index). \(entry.title) by \(entry.subtitle ?? "Unknown")")
    }

    // MARK: - Helpers

    /// Extracts artwork from a queue entry's underlying item.
    private func entryArtwork(_ entry: MusicPlayer.Queue.Entry) -> MusicKit.Artwork? {
        if case .song(let song) = entry.item {
            return song.artwork
        }
        return nil
    }
}
