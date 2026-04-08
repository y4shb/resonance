//
//  QueueItem.swift
//  Resonance
//
//  Model representing a precomputed queue entry from the AI decision engine.
//  Wraps a SongScore with a short explanation and metadata needed by QueueView.
//

import Foundation

// MARK: - QueueItem

/// A single entry in the AI-precomputed queue.
///
/// Wraps a `SongScore` with a human-readable explanation and a stable identity
/// for SwiftUI list diffing. The `appleMusicId` is resolved at creation time
/// so the view can look up MusicKit artwork without a Core Data fetch.
public struct QueueItem: Identifiable, Sendable, Equatable {
    /// Stable identity for SwiftUI (distinct from songId to allow the same
    /// song to appear at different queue positions in theory).
    public let id: UUID

    /// The full SongScore breakdown from the decision engine.
    public let songScore: SongScore

    /// One-line AI reasoning for why this song is queued (e.g., "To energize: great tempo match").
    public let shortExplanation: String

    /// Apple Music catalog/library ID for artwork lookup via MusicKit.
    /// Resolved from Core Data at queue-build time so the view layer
    /// does not need to touch the persistence stack.
    public let appleMusicId: String

    /// Position in the queue (1-based). Mutable to support reordering.
    public var position: Int

    /// Whether the user has manually pinned this item (drag-reordered).
    /// Pinned items survive queue refreshes; unpinned items may be replaced.
    public var isPinned: Bool

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        songScore: SongScore,
        shortExplanation: String,
        appleMusicId: String,
        position: Int,
        isPinned: Bool = false
    ) {
        self.id = id
        self.songScore = songScore
        self.shortExplanation = shortExplanation
        self.appleMusicId = appleMusicId
        self.position = position
        self.isPinned = isPinned
    }

    // MARK: - Equatable

    public static func == (lhs: QueueItem, rhs: QueueItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Convenience Accessors

extension QueueItem {
    /// Song title (forwarded from SongScore).
    public var songTitle: String { songScore.songTitle }

    /// Artist name (forwarded from SongScore).
    public var artistName: String { songScore.artistName }

    /// Album name (forwarded from SongScore).
    public var albumName: String { songScore.albumName }

    /// AI confidence for this pick (0.0 - 1.0).
    public var confidence: Double { songScore.confidence }

    /// Final composite score (0.0 - 1.0).
    public var finalScore: Double { songScore.finalScore }

    /// BPM of the song.
    public var bpm: Double { songScore.bpm }
}

// MARK: - Factory

extension QueueItem {
    /// Creates a placeholder QueueItem for previews and testing.
    public static func placeholder(position: Int = 1) -> QueueItem {
        QueueItem(
            songScore: .placeholder(),
            shortExplanation: "Tempo matches your current energy",
            appleMusicId: "",
            position: position
        )
    }
}
