//
//  PlaylistRepository.swift
//  Resonance
//
//  Core Data repository for Playlist entities.
//  Handles syncing from MusicKit, querying, and aggregate recalculation.
//

import CoreData
import Foundation
import MusicKit

// MARK: - PlaylistRepository

/// Manages persistence operations for Playlist entities.
final class PlaylistRepository {

    // MARK: - Properties

    private let persistence: PersistenceController

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Sync

    /// Syncs a collection of MusicKit playlists into Core Data.
    ///
    /// For each playlist in the collection the method checks whether a matching
    /// `Playlist` record already exists (by `appleMusicId`).  If it does, the
    /// record is updated in place; otherwise a new record is inserted.
    /// `lastSyncedAt` is always refreshed to the current date so callers can
    /// reason about staleness.
    ///
    /// - Parameter playlists: The collection returned by MusicKit.
    func syncPlaylists(from playlists: MusicItemCollection<MusicKit.Playlist>) async throws {
        let playlistArray = Array(playlists)
        let syncDate = Date()

        logInfo(
            "Starting playlist sync: \(playlistArray.count) playlists from MusicKit",
            category: .persistence
        )

        try await persistence.performBackgroundTask { context in
            var created = 0
            var updated = 0

            for mkPlaylist in playlistArray {
                let appleMusicId = mkPlaylist.id.rawValue

                // Fetch existing record, if any.
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Playlist")
                fetchRequest.predicate = NSPredicate(
                    format: "appleMusicId == %@", appleMusicId
                )
                fetchRequest.fetchLimit = 1

                let results = try context.fetch(fetchRequest)
                let playlist: NSManagedObject

                if let existing = results.first {
                    playlist = existing
                    updated += 1
                } else {
                    playlist = NSEntityDescription.insertNewObject(
                        forEntityName: "Playlist",
                        into: context
                    )
                    playlist.setValue(UUID(), forKey: "id")
                    playlist.setValue(Date(), forKey: "createdAt")
                    created += 1
                }

                // Always update mutable fields.
                playlist.setValue(appleMusicId, forKey: "appleMusicId")
                playlist.setValue(mkPlaylist.name, forKey: "name")
                playlist.setValue(syncDate, forKey: "lastSyncedAt")

                // Optional metadata fields.
                if let description = mkPlaylist.standardDescription {
                    playlist.setValue(description, forKey: "descriptionText")
                }

                if let artwork = mkPlaylist.artwork {
                    let artworkURL = artwork.url(width: 300, height: 300)?.absoluteString
                    playlist.setValue(artworkURL, forKey: "artworkURL")
                }
            }

            if context.hasChanges {
                try context.save()
            }

            logInfo(
                "Playlist sync complete — created: \(created), updated: \(updated)",
                category: .persistence
            )
        }
    }

    // MARK: - Fetch

    /// Returns all persisted playlists sorted by `lastPlayedAt` descending.
    /// Playlists with a `nil` `lastPlayedAt` appear at the end of the list.
    ///
    /// - Returns: An array of `Playlist` managed objects.
    func fetchAll() -> [Playlist] {
        let request = NSFetchRequest<Playlist>(entityName: "Playlist")

        // NSSortDescriptor with `ascending: false` pushes nil dates to the
        // bottom automatically when `nullSmallest` handling is the default.
        request.sortDescriptors = [
            NSSortDescriptor(key: "lastPlayedAt", ascending: false)
        ]

        do {
            return try persistence.viewContext.fetch(request)
        } catch {
            logError(
                "Failed to fetch all playlists",
                error: error,
                category: .persistence
            )
            return []
        }
    }

    /// Finds a single `Playlist` by its Apple Music identifier.
    ///
    /// - Parameter appleMusicId: The `id.rawValue` from a MusicKit `Playlist`.
    /// - Returns: The matching `Playlist`, or `nil` if none exists.
    func findByAppleMusicId(_ appleMusicId: String) -> Playlist? {
        let request = NSFetchRequest<Playlist>(entityName: "Playlist")
        request.predicate = NSPredicate(
            format: "appleMusicId == %@", appleMusicId
        )
        request.fetchLimit = 1

        do {
            return try persistence.viewContext.fetch(request).first
        } catch {
            logError(
                "Failed to find playlist with appleMusicId '\(appleMusicId)'",
                error: error,
                category: .persistence
            )
            return nil
        }
    }

    /// Searches playlists whose name contains the given query string.
    ///
    /// The comparison is case- and diacritic-insensitive (`[cd]`).
    ///
    /// - Parameter query: The search term.
    /// - Returns: All matching `Playlist` objects sorted alphabetically.
    func search(query: String) -> [Playlist] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return fetchAll()
        }

        let request = NSFetchRequest<Playlist>(entityName: "Playlist")
        request.predicate = NSPredicate(
            format: "name CONTAINS[cd] %@", query
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true)
        ]

        do {
            return try persistence.viewContext.fetch(request)
        } catch {
            logError(
                "Failed to search playlists for query '\(query)'",
                error: error,
                category: .persistence
            )
            return []
        }
    }

    // MARK: - Aggregates

    /// Recalculates aggregate audio-feature metrics for a playlist from its
    /// associated `Song` records and persists the result.
    ///
    /// Currently computes `avgBPM` as the arithmetic mean of the BPM values of
    /// all songs linked to the playlist.  Songs with a BPM of 0 (meaning the
    /// feature has not yet been analysed) are excluded from the average so they
    /// do not skew the result.
    ///
    /// - Parameter playlist: The `Playlist` whose aggregates should be refreshed.
    func recalculateAggregates(for playlist: Playlist) async {
        let objectID = playlist.objectID

        await persistence.performBackgroundTask { context in
            do {
                guard let backgroundPlaylist = try context.existingObject(with: objectID) as? Playlist else {
                    logWarning(
                        "recalculateAggregates: could not find playlist in background context",
                        category: .persistence
                    )
                    return
                }

                // Gather the linked songs.
                let songs = (backgroundPlaylist.songs?.allObjects as? [Song]) ?? []

                // Compute avgBPM, ignoring songs that have not yet been analysed.
                let analysedBPMs = songs.map { $0.bpm }.filter { $0 > 0 }
                let avgBPM: Double
                if analysedBPMs.isEmpty {
                    avgBPM = 0.0
                } else {
                    avgBPM = analysedBPMs.reduce(0.0, +) / Double(analysedBPMs.count)
                }

                backgroundPlaylist.avgBPM = avgBPM
                backgroundPlaylist.songCount = Int64(songs.count)

                if context.hasChanges {
                    try context.save()
                }

                logDebug(
                    "Recalculated aggregates for '\(backgroundPlaylist.name)': avgBPM=\(String(format: "%.1f", avgBPM)), songCount=\(songs.count)",
                    category: .persistence
                )
            } catch {
                logError(
                    "Failed to recalculate aggregates for playlist",
                    error: error,
                    category: .persistence
                )
            }
        }
    }
}
