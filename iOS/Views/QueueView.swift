//
//  QueueView.swift
//  Resonance
//
//  Displays the AI-precomputed upcoming queue with per-song reasoning.
//  Presented as a half-sheet / full-sheet from NowPlayingView.
//
//  Features:
//  - Now-playing header with current song info
//  - AI queue items with album art, title, artist, and one-line AI reasoning
//  - Drag-to-reorder (pinned items survive auto-refresh)
//  - Swipe-to-remove
//  - Confidence indicator per track
//  - Pull-to-refresh / toolbar refresh button
//

import SwiftUI
import MusicKit

// MARK: - Queue View

struct QueueView: View {
    @Bindable var viewModel: NowPlayingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.retroAccentColor) private var accentColor
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.aiQueueItems.isEmpty && viewModel.isLoadingQueue {
                    queueLoadingView
                } else if viewModel.aiQueueItems.isEmpty {
                    queueEmptyView
                } else {
                    queueListView
                }
            }
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    } label: {
                        Text(editMode == .active ? "Done" : "Edit")
                    }
                    .disabled(viewModel.aiQueueItems.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Refresh button
                        Button {
                            viewModel.refreshQueue(force: true)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoadingQueue)
                        .accessibilityLabel("Refresh queue")

                        Button("Done") { dismiss() }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .onAppear {
                // Trigger queue computation when the sheet opens
                if viewModel.aiQueueItems.isEmpty {
                    viewModel.refreshQueue(force: true)
                }
            }
        }
    }

    // MARK: - Queue List

    private var queueListView: some View {
        List {
            // Now Playing section
            Section {
                nowPlayingRow
                    .listRowBackground(ResonanceColors.metalDark.opacity(0.3))
            } header: {
                Text("NOW PLAYING").retroEngravedLabel()
            }

            // AI Queue section
            Section {
                ForEach(viewModel.aiQueueItems) { item in
                    aiQueueRow(item: item)
                }
                .onDelete { offsets in
                    viewModel.removeQueueItems(at: offsets)
                }
                .onMove { source, destination in
                    viewModel.moveQueueItems(from: source, to: destination)
                }
                .listRowBackground(ResonanceColors.metalDark.opacity(0.3))
            } header: {
                HStack {
                    Text("AI QUEUE (\(viewModel.aiQueueItems.count))").retroEngravedLabel()
                    Spacer()
                    if viewModel.isLoadingQueue {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            } footer: {
                if viewModel.hasUserEditedQueue {
                    Label("You've customized the queue. The AI will respect your order.",
                          systemImage: "hand.raised.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // MusicKit queue fallback section (if any non-AI entries exist)
            let mkEntries = viewModel.queueEntries
            if !mkEntries.isEmpty {
                Section {
                    ForEach(Array(mkEntries.enumerated()), id: \.offset) { _, entry in
                        musicKitEntryRow(entry: entry)
                    }
                    .listRowBackground(ResonanceColors.metalDark.opacity(0.3))
                } header: {
                    Text("From Apple Music Queue")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.refreshQueue(force: true)
            // Wait briefly for the async result to land
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    // MARK: - Now Playing Row (Cassette Style)

    private var nowPlayingRow: some View {
        HStack(spacing: 12) {
            // Mini cassette thumbnail
            MiniCassetteView(
                artwork: viewModel.currentSong.artwork,
                title: "",
                width: 80
            )
            .rotation3DEffect(.degrees(3), axis: (x: 1, y: 0, z: 0), perspective: 0.5)

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.currentSong.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(viewModel.currentSong.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let explanation = viewModel.currentExplanation {
                    Text(explanation.short)
                        .font(.caption2)
                        .foregroundStyle(ResonanceColors.accent)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: viewModel.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                .font(.caption)
                .foregroundStyle(ResonanceColors.accent)
                .symbolEffect(.variableColor.iterative, isActive: viewModel.isPlaying)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(viewModel.currentSong.title) by \(viewModel.currentSong.artistName)")
    }

    // MARK: - AI Queue Row

    private func aiQueueRow(item: QueueItem) -> some View {
        HStack(spacing: 12) {
            // Album artwork thumbnail (48pt)
            ArtworkView(appleMusicId: item.appleMusicId, size: 48)
                .cornerRadius(8)

            // Song info + AI reasoning
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.songTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    // Pinned indicator
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                }

                Text(item.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // AI reasoning one-liner
                RetroLCDPanel {
                    Text(item.shortExplanation)
                        .font(RetroTypography.lcdCaption)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                }
            }

            Spacer(minLength: 4)

            // Confidence indicator
            confidenceIndicator(confidence: item.confidence)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(item.position). \(item.songTitle) by \(item.artistName). "
            + "\(item.shortExplanation). "
            + "Confidence: \(Int(item.confidence * 100)) percent"
        )
        .accessibilityHint(item.isPinned ? "Pinned by you" : "Swipe to remove, drag to reorder")
    }

    // MARK: - Confidence Indicator

    private func confidenceIndicator(confidence: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RetroLEDIndicator(
                    isOn: Double(i) / 5.0 < confidence,
                    color: i < 3 ? ResonanceColors.ledGreen : (i < 4 ? ResonanceColors.ledAmber : ResonanceColors.ledRed),
                    size: 5
                )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - MusicKit Queue Entry Row (Fallback)

    private func musicKitEntryRow(entry: MusicPlayer.Queue.Entry) -> some View {
        HStack(spacing: 12) {
            if let artwork = entryArtwork(entry) {
                ArtworkImage(artwork, width: 40, height: 40)
                    .cornerRadius(6)
            } else {
                artworkPlaceholder(size: 40, cornerRadius: 6)
            }

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
        .accessibilityLabel("\(entry.title) by \(entry.subtitle ?? "Unknown")")
    }

    // MARK: - Empty & Loading States

    private var queueEmptyView: some View {
        ContentUnavailableView(
            "No Queue Yet",
            systemImage: "wand.and.stars",
            description: Text(
                viewModel.activePlaylistName != nil
                    ? "Tap the refresh button or start playing to build your AI queue."
                    : "Select a playlist to start your AI DJ session."
            )
        )
    }

    private var queueLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Building your queue...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("The AI is scoring candidates based on your current state")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func artworkPlaceholder(size: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(.secondary)
            )
    }

    /// Extracts artwork from a MusicKit queue entry.
    private func entryArtwork(_ entry: MusicPlayer.Queue.Entry) -> MusicKit.Artwork? {
        if case .song(let song) = entry.item {
            return song.artwork
        }
        return nil
    }
}

// MARK: - Artwork View (Async Loading from Apple Music ID)

/// Loads album artwork from an Apple Music ID asynchronously.
/// Shows a placeholder while loading.
private struct ArtworkView: View {
    let appleMusicId: String
    let size: CGFloat

    @State private var artwork: MusicKit.Artwork?
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if let artwork {
                ArtworkImage(artwork, width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)
                    .overlay(
                        Group {
                            if hasLoaded {
                                Image(systemName: "music.note")
                                    .font(.system(size: size * 0.35))
                                    .foregroundStyle(.secondary)
                            } else {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                        }
                    )
            }
        }
        .task {
            guard !appleMusicId.isEmpty, !hasLoaded else { return }
            await loadArtwork()
        }
    }

    private func loadArtwork() async {
        defer { hasLoaded = true }
        do {
            var request = MusicLibraryRequest<MusicKit.Song>()
            request.filter(matching: \.id, equalTo: MusicItemID(rawValue: appleMusicId))
            let response = try await request.response()
            artwork = response.items.first?.artwork
        } catch {
            // Silently fail -- placeholder will remain
        }
    }
}

// MARK: - Preview

#Preview("Queue with items") {
    QueueView(
        viewModel: NowPlayingViewModel(musicService: MusicKitService())
    )
}
