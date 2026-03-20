//
//  LibraryAnalysisEngine.swift
//  Resonance
//
//  Performs a full library analysis on first launch by fetching all songs
//  from the user's Apple Music library, syncing them to Core Data, running
//  feature extraction, and classifying each song by emotion category.
//

#if os(iOS)

import CoreData
import Foundation
import MusicKit
import Observation

// MARK: - Library Analysis Engine

/// Orchestrates a full scan of the user's Apple Music library on first launch.
///
/// The engine fetches every song from the library using offset-based pagination,
/// upserts each song into Core Data, runs the `FeatureExtractor` to estimate
/// audio features, and classifies each song into an `EmotionCategory`.
@MainActor
@Observable
final class LibraryAnalysisEngine {

    // MARK: - Published State

    /// Overall progress from 0.0 to 1.0.
    var progress: Double = 0.0

    /// Total number of songs discovered in the library.
    var totalSongs: Int = 0

    /// Number of songs that have been analyzed so far.
    var analyzedSongs: Int = 0

    /// Description of the current analysis phase (e.g., "Fetching library...", "Analyzing features...").
    var currentPhase: String = "Preparing..."

    /// Whether the full analysis has completed.
    var isComplete: Bool = false

    // MARK: - Constants

    /// Number of songs to fetch per page from MusicKit.
    private static let fetchBatchSize = 200

    /// Number of songs to process in a single Core Data save batch.
    private static let processingBatchSize = 50

    // MARK: - Full Library Analysis

    /// Performs a complete analysis of the user's Apple Music library.
    ///
    /// This method:
    /// 1. Fetches all songs via `MusicLibraryRequest` with offset pagination.
    /// 2. Upserts each song into Core Data.
    /// 3. Runs `FeatureExtractor` to estimate energy, valence, BPM, etc.
    /// 4. Classifies each song into an `EmotionCategory`.
    ///
    /// Progress is reported on the main actor for SwiftUI binding.
    ///
    /// - Parameters:
    ///   - musicService: The MusicKit service (must be authorized).
    ///   - featureExtractor: The feature extraction engine.
    ///   - songRepository: The Core Data song repository.
    ///   - persistence: The persistence controller for background contexts.
    func analyzeFullLibrary(
        musicService: MusicKitService,
        featureExtractor: FeatureExtractor,
        songRepository: SongRepository,
        persistence: PersistenceController = .shared
    ) async {
        logInfo("Starting full library analysis", category: .background)

        // Phase 1: Fetch all songs from the library
        await updatePhase("Scanning your library...")

        let allSongs: [MusicKit.Song]
        do {
            allSongs = try await fetchAllLibrarySongs()
        } catch {
            logError("Library analysis failed during fetch", error: error, category: .background)
            await updatePhase("Analysis failed")
            return
        }

        guard !allSongs.isEmpty else {
            logInfo("Library is empty, nothing to analyze", category: .background)
            await finishAnalysis()
            return
        }

        totalSongs = allSongs.count

        logInfo("Fetched \(allSongs.count) songs from library", category: .background)

        // Phase 2: Sync songs to Core Data and extract features
        await updatePhase("Analyzing features...")

        let batches = stride(from: 0, to: allSongs.count, by: Self.processingBatchSize)
            .map { startIndex in
                let endIndex = min(startIndex + Self.processingBatchSize, allSongs.count)
                return Array(allSongs[startIndex..<endIndex])
            }

        for batch in batches {
            if Task.isCancelled {
                logInfo("Library analysis cancelled", category: .background)
                await updatePhase("Analysis cancelled")
                return
            }

            do {
                try await processBatch(
                    batch,
                    featureExtractor: featureExtractor,
                    persistence: persistence
                )
            } catch {
                logError(
                    "Failed to process batch during library analysis",
                    error: error,
                    category: .background
                )
                // Continue with next batch rather than aborting entirely
            }

            analyzedSongs = min(analyzedSongs + batch.count, totalSongs)
            if totalSongs > 0 {
                progress = Double(analyzedSongs) / Double(totalSongs)
            }
        }

        // Phase 3: Finalize
        await finishAnalysis()
    }

    // MARK: - Private: Fetch All Songs

    /// Fetches every song from the user's Apple Music library using offset pagination.
    private func fetchAllLibrarySongs() async throws -> [MusicKit.Song] {
        var allSongs: [MusicKit.Song] = []
        var offset = 0
        var hasMore = true

        while hasMore {
            if Task.isCancelled { break }

            var request = MusicLibraryRequest<MusicKit.Song>()
            request.limit = Self.fetchBatchSize
            request.offset = offset

            let response = try await request.response()
            let fetched = Array(response.items)

            allSongs.append(contentsOf: fetched)

            logDebug(
                "Fetched \(fetched.count) songs (offset: \(offset), total so far: \(allSongs.count))",
                category: .background
            )

            totalSongs = allSongs.count
            currentPhase = "Scanning your library... (\(allSongs.count) songs found)"

            if fetched.count < Self.fetchBatchSize {
                hasMore = false
            } else {
                offset += fetched.count
            }
        }

        return allSongs
    }

    // MARK: - Private: Process Batch

    /// Upserts a batch of MusicKit songs into Core Data and runs feature extraction.
    private func processBatch(
        _ songs: [MusicKit.Song],
        featureExtractor: FeatureExtractor,
        persistence: PersistenceController
    ) async throws {
        try await persistence.performBackgroundTask { context in
            // Batch-fetch existing songs by Apple Music ID
            let appleMusicIds = songs.map { $0.id.rawValue }
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Song")
            fetchRequest.predicate = NSPredicate(format: "appleMusicId IN %@", appleMusicIds)
            let existingObjects = try context.fetch(fetchRequest)

            var existingById: [String: NSManagedObject] = [:]
            for obj in existingObjects {
                if let amid = obj.value(forKey: "appleMusicId") as? String {
                    existingById[amid] = obj
                }
            }

            for mkSong in songs {
                let appleMusicId = mkSong.id.rawValue

                let song: NSManagedObject
                if let existing = existingById[appleMusicId] {
                    song = existing
                } else {
                    song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context)
                    song.setValue(UUID(), forKey: "id")
                }

                // Sync metadata
                song.setValue(appleMusicId, forKey: "appleMusicId")
                song.setValue(mkSong.title, forKey: "title")
                song.setValue(mkSong.artistName, forKey: "artistName")

                if let albumTitle = mkSong.albumTitle {
                    song.setValue(albumTitle, forKey: "albumName")
                }

                song.setValue(mkSong.duration ?? 0.0, forKey: "durationSeconds")

                if let artwork = mkSong.artwork {
                    let artworkURL = artwork.url(width: 300, height: 300)?.absoluteString
                    song.setValue(artworkURL, forKey: "artworkURL")
                }

                if !mkSong.genreNames.isEmpty {
                    song.setValue(mkSong.genreNames, forKey: "genreNames")
                }

                if let releaseDate = mkSong.releaseDate {
                    song.setValue(releaseDate, forKey: "releaseDate")
                }

                if let libraryAddedDate = mkSong.libraryAddedDate {
                    song.setValue(libraryAddedDate, forKey: "addedToLibraryAt")
                }

                // Run feature extraction on the Song managed object
                if let coreDataSong = song as? Song {
                    featureExtractor.extractFeatures(for: coreDataSong, in: context)
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    // MARK: - Private: State Updates

    private func updatePhase(_ phase: String) {
        currentPhase = phase
    }

    private func finishAnalysis() {
        progress = 1.0
        isComplete = true
        currentPhase = "Analysis complete"
        logInfo(
            "Library analysis complete -- \(analyzedSongs) of \(totalSongs) songs processed",
            category: .background
        )
    }
}

#endif
