//
//  SongRepository.swift
//  Resonance
//
//  Core Data repository for Song entities.
//  Handles syncing from MusicKit, querying, and playback-statistics updates.
//

import CoreData
import Foundation
import MusicKit

// MARK: - SongRepository

/// Manages persistence operations for Song entities.
final class SongRepository {

    // MARK: - Properties

    private let persistence: PersistenceController

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Sync

    /// Syncs a collection of MusicKit songs into Core Data and associates them
    /// with the given `Playlist`.
    ///
    /// For each song the method checks whether a `Song` record already exists
    /// (matching on `appleMusicId`).  If it does, mutable metadata is refreshed;
    /// otherwise a new record is inserted.  Deduplication is enforced per Apple
    /// Music identifier so the same track is never stored twice even if it
    /// appears in multiple playlists.  After upsert the song is added to the
    /// playlist's `songs` relationship.
    ///
    /// - Parameters:
    ///   - songs: The MusicKit song collection to persist.
    ///   - playlist: The `Playlist` to which every synced song should belong.
    func syncSongs(
        _ songs: MusicItemCollection<MusicKit.Song>,
        for playlist: Playlist
    ) async throws {
        let songArray = Array(songs)
        let playlistObjectID = playlist.objectID

        logInfo(
            "Starting song sync: \(songArray.count) songs for playlist '\(playlist.name)'",
            category: .persistence
        )

        try await persistence.performBackgroundTask { context in
            guard let backgroundPlaylist = try context.existingObject(with: playlistObjectID) as? Playlist else {
                logWarning(
                    "syncSongs: playlist not found in background context",
                    category: .persistence
                )
                return
            }

            var created = 0
            var updated = 0

            for mkSong in songArray {
                let appleMusicId = mkSong.id.rawValue

                // Check for an existing record.
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Song")
                fetchRequest.predicate = NSPredicate(
                    format: "appleMusicId == %@", appleMusicId
                )
                fetchRequest.fetchLimit = 1

                let results = try context.fetch(fetchRequest)
                let song: NSManagedObject

                if let existing = results.first {
                    song = existing
                    updated += 1
                } else {
                    song = NSEntityDescription.insertNewObject(
                        forEntityName: "Song",
                        into: context
                    )
                    song.setValue(UUID(), forKey: "id")
                    created += 1
                }

                // Core identifiers.
                song.setValue(appleMusicId, forKey: "appleMusicId")

                // Metadata fields — map MusicKit properties to Core Data attributes.
                song.setValue(mkSong.title, forKey: "title")
                song.setValue(mkSong.artistName, forKey: "artistName")

                if let albumTitle = mkSong.albumTitle {
                    song.setValue(albumTitle, forKey: "albumName")
                }

                song.setValue(mkSong.duration ?? 0.0, forKey: "durationSeconds")

                // Artwork URL at 300×300.
                if let artwork = mkSong.artwork {
                    let artworkURL = artwork.url(width: 300, height: 300)?.absoluteString
                    song.setValue(artworkURL, forKey: "artworkURL")
                }

                // Genre names (stored as a Transformable [String]).
                if !mkSong.genreNames.isEmpty {
                    song.setValue(mkSong.genreNames, forKey: "genreNames")
                }

                // Dates.
                if let releaseDate = mkSong.releaseDate {
                    song.setValue(releaseDate, forKey: "releaseDate")
                }

                if let libraryAddedDate = mkSong.libraryAddedDate {
                    song.setValue(libraryAddedDate, forKey: "addedToLibraryAt")
                }

                // Link the song into the playlist's songs relationship.
                // Using the mutable set accessor avoids re-fetching both sides.
                let currentSongs = backgroundPlaylist.mutableSetValue(forKey: "songs")
                currentSongs.add(song)
            }

            // Update the denormalised song count on the playlist.
            let totalSongs = backgroundPlaylist.songs?.count ?? (created + updated)
            backgroundPlaylist.songCount = Int64(totalSongs)

            if context.hasChanges {
                try context.save()
            }

            logInfo(
                "Song sync complete for '\(backgroundPlaylist.name)' — created: \(created), updated: \(updated)",
                category: .persistence
            )
        }
    }

    // MARK: - Fetch

    /// Returns all songs associated with the given playlist.
    ///
    /// - Parameter playlist: The `Playlist` whose songs should be fetched.
    /// - Returns: An array of `Song` objects sorted by title ascending.
    func fetchSongs(for playlist: Playlist) -> [Song] {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(
            format: "ANY playlists == %@", playlist
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "title", ascending: true)
        ]

        do {
            return try persistence.viewContext.fetch(request)
        } catch {
            logError(
                "Failed to fetch songs for playlist '\(playlist.name)'",
                error: error,
                category: .persistence
            )
            return []
        }
    }

    /// Finds a single `Song` by its Apple Music identifier.
    ///
    /// - Parameter appleMusicId: The `id.rawValue` from a MusicKit `Song`.
    /// - Returns: The matching `Song`, or `nil` if none exists.
    func findByAppleMusicId(_ appleMusicId: String) -> Song? {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(
            format: "appleMusicId == %@", appleMusicId
        )
        request.fetchLimit = 1

        do {
            return try persistence.viewContext.fetch(request).first
        } catch {
            logError(
                "Failed to find song with appleMusicId '\(appleMusicId)'",
                error: error,
                category: .persistence
            )
            return nil
        }
    }

    /// Returns songs that still need audio-feature analysis.
    ///
    /// A song is considered to need features when its BPM has not been
    /// determined (`bpm == 0`) or its confidence level is below the threshold
    /// defined in `StateEngineConstants.minimumConfidenceThreshold` (0.3).
    ///
    /// - Parameter limit: The maximum number of records to return.  Defaults to
    ///   50 so callers that process songs in batches don't over-fetch.
    /// - Returns: An array of `Song` objects that require feature extraction.
    func fetchSongsNeedingFeatures(limit: Int = 50) -> [Song] {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(
            format: "bpm == 0 OR confidenceLevel < %f",
            StateEngineConstants.minimumConfidenceThreshold
        )
        // Prioritise songs that have been played most recently so the most
        // relevant songs are processed first.
        request.sortDescriptors = [
            NSSortDescriptor(key: "lastPlayedAt", ascending: false)
        ]
        request.fetchLimit = limit

        do {
            return try persistence.viewContext.fetch(request)
        } catch {
            logError(
                "Failed to fetch songs needing features",
                error: error,
                category: .persistence
            )
            return []
        }
    }

    // MARK: - Playback Statistics

    /// Updates the play/skip counters and last-played timestamp for a song.
    ///
    /// `totalPlayCount` is incremented when the event indicates the song was
    /// not skipped; `totalSkipCount` is incremented when it was skipped.
    /// `lastPlayedAt` is always updated to the event's `startedAt` timestamp,
    /// or the current date if no timestamp is available.
    ///
    /// - Parameters:
    ///   - song: The `Song` to update.
    ///   - event: The `PlaybackEvent` that just ended.
    func updatePlaybackStats(for song: Song, event: PlaybackEvent) {
        let songObjectID = song.objectID
        let wasSkipped = event.wasSkipped
        let eventStartedAt = event.startedAt

        persistence.performBackgroundTask { context in
            do {
                guard let backgroundSong = try context.existingObject(with: songObjectID) as? Song else {
                    logWarning(
                        "updatePlaybackStats: song not found in background context",
                        category: .persistence
                    )
                    return
                }

                if wasSkipped {
                    backgroundSong.totalSkipCount += 1
                    logDebug(
                        "Incremented skip count for '\(backgroundSong.title)' to \(backgroundSong.totalSkipCount)",
                        category: .persistence
                    )
                } else {
                    backgroundSong.totalPlayCount += 1
                    logDebug(
                        "Incremented play count for '\(backgroundSong.title)' to \(backgroundSong.totalPlayCount)",
                        category: .persistence
                    )
                }

                backgroundSong.lastPlayedAt = eventStartedAt

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                logError(
                    "Failed to update playback stats for song",
                    error: error,
                    category: .persistence
                )
            }
        }
    }
}
