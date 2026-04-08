//
//  HistoricalEngine.swift
//  Resonance
//
//  Orchestrates the full historical backfill pipeline.
//  Coordinates SessionReconstructor, SongImpactCalculator, and
//  PlaylistImpactCalculator in sequence, tracks progress via per-step
//  watermarks, and publishes state for Settings UI consumption.
//

#if os(iOS)

import Foundation
import Combine

/// Orchestrates the full historical backfill pipeline.
/// Coordinates SessionReconstructor, SongImpactCalculator, and PlaylistImpactCalculator
/// in sequence, tracks progress, and supports incremental runs via per-step watermarks.
@MainActor
final class HistoricalEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRunning = false
    @Published private(set) var progress: BackfillProgress = .idle

    enum BackfillProgress: Equatable {
        case idle
        case reconstructingSessions
        case calculatingSongImpacts
        case calculatingPlaylistImpacts
        case completed(sessionsCreated: Int, eventsProcessed: Int, playlistsUpdated: Int)
        case failed(String)
    }

    // MARK: - Dependencies

    private let sessionReconstructor: SessionReconstructor
    private let songImpactCalculator: SongImpactCalculator
    private let playlistImpactCalculator: PlaylistImpactCalculator

    // MARK: - Per-Step Watermarks

    /// Watermark for session reconstruction step.
    var sessionWatermark: Date? {
        get {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            return defaults.object(forKey: BackfillConstants.WatermarkKey.sessionReconstruction) as? Date
        }
        set {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            defaults.set(newValue, forKey: BackfillConstants.WatermarkKey.sessionReconstruction)
        }
    }

    /// Watermark for song impact calculation step.
    var songImpactWatermark: Date? {
        get {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            return defaults.object(forKey: BackfillConstants.WatermarkKey.songImpact) as? Date
        }
        set {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            defaults.set(newValue, forKey: BackfillConstants.WatermarkKey.songImpact)
        }
    }

    /// Date of last full backfill completion (all steps succeeded).
    var lastBackfillDate: Date? {
        get {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            return defaults.object(forKey: BackfillConstants.WatermarkKey.lastFullBackfill) as? Date
        }
        set {
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            defaults.set(newValue, forKey: BackfillConstants.WatermarkKey.lastFullBackfill)
        }
    }

    // MARK: - Initialization

    init(
        healthKitService: HealthKitService,
        persistence: PersistenceController = .shared
    ) {
        self.sessionReconstructor = SessionReconstructor(
            persistence: persistence,
            healthKitService: healthKitService
        )
        self.songImpactCalculator = SongImpactCalculator(persistence: persistence)
        self.playlistImpactCalculator = PlaylistImpactCalculator(persistence: persistence)
    }

    // MARK: - Entry Points

    /// Runs the full backfill pipeline (for first-time or "Run Full Backfill" button).
    func runFullBackfill() async {
        guard !isRunning else {
            logWarning("HistoricalEngine: backfill already running", category: .background)
            return
        }
        await runBackfill(since: nil)
    }

    /// Runs an incremental backfill since the last watermark.
    func runIncrementalBackfill() async {
        guard !isRunning else {
            logWarning("HistoricalEngine: incremental backfill skipped (already running)", category: .background)
            return
        }
        await runBackfill(since: lastBackfillDate)
    }

    // MARK: - Pipeline

    private func runBackfill(since: Date?) async {
        isRunning = true
        let isIncremental = since != nil

        logInfo(
            "HistoricalEngine: starting \(isIncremental ? "incremental" : "full") backfill"
            + (since.map { " (since: \($0.description))" } ?? ""),
            category: .background
        )

        do {
            // Step 1: Reconstruct sessions
            progress = .reconstructingSessions
            let sessionSince = since ?? sessionWatermark
            let sessionsCreated = try await sessionReconstructor.reconstructSessions(since: sessionSince)
            sessionWatermark = Date()
            logInfo("HistoricalEngine: created \(sessionsCreated) sessions", category: .background)

            // Step 2: Calculate song impacts
            progress = .calculatingSongImpacts
            let songSince = since ?? songImpactWatermark
            let eventsProcessed = try await songImpactCalculator.calculateImpacts(since: songSince)
            songImpactWatermark = Date()
            logInfo("HistoricalEngine: processed \(eventsProcessed) events for song impacts", category: .background)

            // Step 3: Calculate playlist impacts (always full -- it's fast)
            progress = .calculatingPlaylistImpacts
            let playlistsUpdated = try await playlistImpactCalculator.calculatePlaylistImpacts()
            logInfo("HistoricalEngine: updated \(playlistsUpdated) playlists", category: .background)

            // Update full-run watermark
            lastBackfillDate = Date()

            progress = .completed(
                sessionsCreated: sessionsCreated,
                eventsProcessed: eventsProcessed,
                playlistsUpdated: playlistsUpdated
            )
            isRunning = false

            logInfo(
                "HistoricalEngine: backfill complete -- "
                + "\(sessionsCreated) sessions, \(eventsProcessed) events, \(playlistsUpdated) playlists",
                category: .background
            )
        } catch is CancellationError {
            progress = .failed("Cancelled by system")
            isRunning = false
            logInfo("HistoricalEngine: backfill cancelled (BGTask expired or user cancelled)", category: .background)
        } catch {
            progress = .failed(error.localizedDescription)
            isRunning = false
            logError("HistoricalEngine: backfill failed", error: error, category: .background)
        }
    }
}

#endif
