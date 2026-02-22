//
//  PlaylistImpactCalculator.swift
//  Resonance
//
//  Aggregates SongEffect scores across playlists to populate playlist-level
//  effect metrics and context associations.
//

#if os(iOS)

import Foundation
import CoreData

final class PlaylistImpactCalculator {

    // MARK: - Properties

    private let persistence: PersistenceController

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Main Entry Point

    /// Calculates aggregated impact metrics for all playlists that contain
    /// songs with effect data. Uses confidence-weighted averaging at both
    /// the song and playlist levels.
    ///
    /// - Returns: The number of playlists that were updated.
    @discardableResult
    func calculatePlaylistImpacts() async throws -> Int {
        logInfo("Starting playlist impact calculation", category: .background)

        let context = persistence.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        let updatedCount: Int = try await context.perform {
            // Fetch all playlists
            let request = NSFetchRequest<Playlist>(entityName: "Playlist")
            let playlists = try context.fetch(request)

            logDebug("Fetched \(playlists.count) playlists for impact calculation", category: .background)

            var updated = 0

            for playlist in playlists {
                if self.processPlaylist(playlist, in: context) {
                    updated += 1
                }
            }

            // Save all changes at once
            if context.hasChanges {
                try context.save()
                logDebug("Saved playlist impact updates to Core Data", category: .background)
            }

            return updated
        }

        logInfo("Playlist impact calculation complete: updated \(updatedCount) playlists", category: .background)
        return updatedCount
    }

    // MARK: - Process Individual Playlist

    /// Processes a single playlist by computing confidence-weighted averages
    /// of its songs' effect scores and building context associations from
    /// linked sessions.
    ///
    /// - Parameters:
    ///   - playlist: The Playlist entity to update.
    ///   - context: The managed object context to work within.
    /// - Returns: `true` if the playlist was updated, `false` if skipped.
    @discardableResult
    private func processPlaylist(_ playlist: Playlist, in context: NSManagedObjectContext) -> Bool {
        guard let songs = playlist.songs?.allObjects as? [Song], !songs.isEmpty else {
            logDebug(
                "Skipping playlist '\(playlist.name ?? "unknown")': no songs",
                category: .background
            )
            return false
        }

        // Confidence-weighted averaging across songs
        var totalWeight = 0.0
        var weightedCalm = 0.0
        var weightedFocus = 0.0
        var weightedEnergy = 0.0
        var songsWithEffects = 0

        for song in songs {
            guard let effects = song.effects?.allObjects as? [SongEffect], !effects.isEmpty else {
                continue
            }

            let songWeight = effects.reduce(0.0) { $0 + $1.confidenceLevel }
            guard songWeight > 0 else { continue }

            // Song-level averages (confidence-weighted across effects)
            let songCalm = effects.reduce(0.0) { $0 + $1.calmScore * $1.confidenceLevel } / songWeight
            let songFocus = effects.reduce(0.0) { $0 + $1.focusScore * $1.confidenceLevel } / songWeight
            let songEnergy = effects.reduce(0.0) { $0 + $1.energyScore * $1.confidenceLevel } / songWeight

            // Average confidence for this song (used as weight at playlist level)
            let avgConfidence = songWeight / Double(effects.count)

            weightedCalm += songCalm * avgConfidence
            weightedFocus += songFocus * avgConfidence
            weightedEnergy += songEnergy * avgConfidence
            totalWeight += avgConfidence
            songsWithEffects += 1
        }

        guard songsWithEffects > 0, totalWeight > 0 else {
            logDebug(
                "Skipping playlist '\(playlist.name ?? "unknown")': no songs with effect data",
                category: .background
            )
            return false
        }

        // Playlist-level scores (confidence-weighted average across songs)
        playlist.avgCalmEffect = weightedCalm / totalWeight
        playlist.avgFocusEffect = weightedFocus / totalWeight
        playlist.avgEnergyEffect = weightedEnergy / totalWeight

        // Overall playlist confidence: average weight scaled by coverage
        let coverage = Double(songsWithEffects) / Double(songs.count)
        playlist.effectConfidence = (totalWeight / Double(songsWithEffects)) * coverage

        // Build context associations from linked sessions
        if let sessions = playlist.sessions?.allObjects as? [HistoricalSession], !sessions.isEmpty {
            let associations = buildContextAssociations(from: sessions)
            if let jsonData = try? JSONSerialization.data(withJSONObject: associations, options: []) {
                playlist.contextAssociations = jsonData
            }
        }

        logDebug(
            "Updated playlist '\(playlist.name ?? "unknown")': "
            + "calm=\(String(format: "%.3f", playlist.avgCalmEffect)), "
            + "focus=\(String(format: "%.3f", playlist.avgFocusEffect)), "
            + "energy=\(String(format: "%.3f", playlist.avgEnergyEffect)), "
            + "confidence=\(String(format: "%.3f", playlist.effectConfidence)), "
            + "songsWithEffects=\(songsWithEffects)/\(songs.count)",
            category: .background
        )

        return true
    }

    // MARK: - Context Associations

    /// Builds a context association dictionary from the playlist's linked sessions.
    ///
    /// Groups sessions by `contextType` and produces frequency (proportion) and
    /// count for each context type.
    ///
    /// - Parameter sessions: The `HistoricalSession` entities linked to the playlist.
    /// - Returns: A dictionary mapping each context type to its frequency and count,
    ///   e.g. `{ "workout": { "frequency": 0.4, "count": 5 } }`.
    private func buildContextAssociations(from sessions: [HistoricalSession]) -> [String: [String: Double]] {
        var contextCounts: [String: Int] = [:]

        for session in sessions {
            let contextType = session.contextType ?? "unknown"
            contextCounts[contextType, default: 0] += 1
        }

        let totalSessions = Double(sessions.count)
        var associations: [String: [String: Double]] = [:]

        for (contextType, count) in contextCounts {
            associations[contextType] = [
                "frequency": Double(count) / totalSessions,
                "count": Double(count)
            ]
        }

        return associations
    }
}

#endif
