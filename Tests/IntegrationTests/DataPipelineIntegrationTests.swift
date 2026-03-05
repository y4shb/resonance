//
//  DataPipelineIntegrationTests.swift
//  ResonanceTests
//
//  Integration tests for the full data pipeline:
//  PlaybackEvent → ImpactScore → SongEffect (EMA) → Song aggregates → Playlist aggregates
//
//  Validates the isImpactProcessed double-counting guard, moodLiftScore aggregation
//  at Song and Playlist levels, and confidence-weighted averaging.
//

import XCTest
import CoreData
@testable import Resonance

final class DataPipelineIntegrationTests: XCTestCase {

    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        context = persistence.viewContext
    }

    override func tearDown() {
        persistence = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a Song entity with sensible defaults.
    private func makeSong(
        title: String = "Test Song",
        artistName: String = "Test Artist",
        bpm: Double = 120,
        energy: Double = 0.5
    ) -> Song {
        let song = NSEntityDescription.insertNewObject(forEntityName: "Song", into: context) as! Song
        song.id = UUID()
        song.appleMusicId = "apple_\(UUID().uuidString.prefix(8))"
        song.title = title
        song.artistName = artistName
        song.bpm = bpm
        song.energyEstimate = energy
        song.durationSeconds = 240
        song.calmScore = 0.5
        song.focusScore = 0.5
        song.activationScore = 0.5
        song.moodLiftScore = 0.5
        song.confidenceLevel = 0.0
        song.totalPlayCount = 0
        song.totalSkipCount = 0
        return song
    }

    /// Creates a Playlist entity.
    private func makePlaylist(
        name: String = "Test Playlist"
    ) -> Playlist {
        let playlist = NSEntityDescription.insertNewObject(forEntityName: "Playlist", into: context) as! Playlist
        playlist.id = UUID()
        playlist.appleMusicId = "playlist_\(UUID().uuidString.prefix(8))"
        playlist.name = name
        playlist.avgCalmEffect = 0.5
        playlist.avgFocusEffect = 0.5
        playlist.avgEnergyEffect = 0.5
        playlist.avgMoodLiftEffect = 0.5
        playlist.effectConfidence = 0.0
        return playlist
    }

    /// Creates a SongEffect entity with specified scores.
    private func makeSongEffect(
        for song: Song,
        contextType: String = "any",
        calmScore: Double = 0.5,
        focusScore: Double = 0.5,
        energyScore: Double = 0.5,
        moodLiftScore: Double = 0.5,
        confidenceLevel: Double = 0.5,
        sampleCount: Int64 = 10
    ) -> SongEffect {
        let effect = NSEntityDescription.insertNewObject(forEntityName: "SongEffect", into: context) as! SongEffect
        effect.id = UUID()
        effect.song = song
        effect.contextType = contextType
        effect.timeOfDaySlot = "any"
        effect.calmScore = calmScore
        effect.focusScore = focusScore
        effect.energyScore = energyScore
        effect.moodLiftScore = moodLiftScore
        effect.confidenceLevel = confidenceLevel
        effect.sampleCount = sampleCount
        effect.firstRecordedAt = Date()
        effect.lastUpdatedAt = Date()
        return effect
    }

    /// Creates a HistoricalSession entity.
    private func makeSession(
        contextType: String = "work",
        timeOfDaySlot: String = "afternoon"
    ) -> HistoricalSession {
        let session = NSEntityDescription.insertNewObject(forEntityName: "HistoricalSession", into: context) as! HistoricalSession
        session.id = UUID()
        session.startTime = Date().addingTimeInterval(-3600)
        session.endTime = Date()
        session.durationMinutes = 60
        session.contextType = contextType
        session.timeOfDaySlot = timeOfDaySlot
        session.dayOfWeek = 3
        return session
    }

    /// Creates a PlaybackEvent entity.
    private func makePlaybackEvent(
        song: Song,
        session: HistoricalSession?,
        listenPercentage: Double = 0.85,
        wasSkipped: Bool = false,
        hrvDelta: Double = 0.0,
        hrDelta: Double = 0.0,
        hrAtStart: Double = 0.0,
        hrvAtStart: Double = 0.0,
        isImpactProcessed: Bool = false
    ) -> PlaybackEvent {
        let event = NSEntityDescription.insertNewObject(forEntityName: "PlaybackEvent", into: context) as! PlaybackEvent
        event.id = UUID()
        event.song = song
        event.session = session
        event.startedAt = Date().addingTimeInterval(-300)
        event.endedAt = Date()
        event.durationListened = 200
        event.songDuration = 240
        event.listenPercentage = listenPercentage
        event.wasSkipped = wasSkipped
        event.hrvDelta = hrvDelta
        event.hrDelta = hrDelta
        event.hrAtStart = hrAtStart
        event.hrvAtStart = hrvAtStart
        event.isImpactProcessed = isImpactProcessed
        return event
    }

    // MARK: - 1. ImpactScore Calculation from PlaybackEvent

    func test_impactScore_fullListen_noBiometrics_allDimensionsAboveNeutral() {
        let song = makeSong()
        let event = makePlaybackEvent(
            song: song,
            session: nil,
            listenPercentage: 0.95,
            wasSkipped: false
        )
        try? context.save()

        let impact = ImpactScore.calculate(from: event)

        // Full listen (95%) gives completionBonus = (0.95 - 0.5) * 0.2 = 0.09
        // No biometrics: calm/energy = 0.5 + 0.09 * 2.0 = 0.68
        XCTAssertGreaterThan(impact.calm, 0.5, "Full listen should produce calm > neutral")
        XCTAssertGreaterThan(impact.energy, 0.5, "Full listen should produce energy > neutral")
        XCTAssertGreaterThan(impact.focus, 0.5, "Full listen should produce focus > neutral")
        XCTAssertGreaterThan(impact.moodLift, 0.5, "Full listen should produce moodLift > neutral")
        XCTAssertFalse(impact.wasSkipped)
        XCTAssertFalse(impact.hasBiometricData)
    }

    func test_impactScore_earlySkip_allDimensionsBelowNeutral() {
        let song = makeSong()
        let event = makePlaybackEvent(
            song: song,
            session: nil,
            listenPercentage: 0.05,
            wasSkipped: true
        )
        try? context.save()

        let impact = ImpactScore.calculate(from: event)

        // Early skip (5%): penalty = -0.3, completionBonus = (0.05 - 0.5) * 0.2 = -0.09
        XCTAssertLessThan(impact.calm, 0.5, "Early skip should produce calm < neutral")
        XCTAssertLessThan(impact.energy, 0.5, "Early skip should produce energy < neutral")
        XCTAssertLessThan(impact.focus, 0.5, "Early skip should produce focus < neutral")
        XCTAssertLessThan(impact.moodLift, 0.5, "Early skip should produce moodLift < neutral")
        XCTAssertTrue(impact.wasSkipped)
    }

    func test_impactScore_withBiometrics_hrvUp_calmHighEnergyLow() {
        let song = makeSong()
        let event = makePlaybackEvent(
            song: song,
            session: nil,
            listenPercentage: 0.90,
            wasSkipped: false,
            hrvDelta: 10.0,   // HRV went up → calming
            hrDelta: -5.0,    // HR went down → not energizing
            hrAtStart: 75.0,
            hrvAtStart: 40.0
        )
        try? context.save()

        let impact = ImpactScore.calculate(from: event)

        XCTAssertTrue(impact.hasBiometricData)
        XCTAssertGreaterThan(impact.calm, 0.6, "Positive HRV delta should produce high calm")
        // moodLift is behavior-based, still above neutral for full listen
        XCTAssertGreaterThan(impact.moodLift, 0.5, "Full listen should produce moodLift > neutral")
    }

    // MARK: - 2. SongEffect → Song Aggregate Flow (moodLiftScore)

    func test_songAggregates_includesMoodLiftScore() {
        let song = makeSong()

        // Create two SongEffects with different moodLiftScores
        let _ = makeSongEffect(
            for: song,
            contextType: "work",
            calmScore: 0.8,
            focusScore: 0.7,
            energyScore: 0.3,
            moodLiftScore: 0.9,
            confidenceLevel: 0.8,
            sampleCount: 15
        )

        let _ = makeSongEffect(
            for: song,
            contextType: "workout",
            calmScore: 0.3,
            focusScore: 0.4,
            energyScore: 0.9,
            moodLiftScore: 0.6,
            confidenceLevel: 0.4,
            sampleCount: 5
        )

        try? context.save()

        // Run the aggregate update
        SongEffectHelper.updateSongAggregates(song, in: context)

        // Confidence-weighted average:
        // totalWeight = 0.8 + 0.4 = 1.2
        // weightedMoodLift = 0.9 * 0.8 + 0.6 * 0.4 = 0.72 + 0.24 = 0.96
        // song.moodLiftScore = 0.96 / 1.2 = 0.8
        let expectedMoodLift = (0.9 * 0.8 + 0.6 * 0.4) / (0.8 + 0.4)
        XCTAssertEqual(song.moodLiftScore, expectedMoodLift, accuracy: 0.001,
                       "Song moodLiftScore should be confidence-weighted average across SongEffects")

        // Verify other dimensions are also aggregated
        let expectedCalm = (0.8 * 0.8 + 0.3 * 0.4) / 1.2
        XCTAssertEqual(song.calmScore, expectedCalm, accuracy: 0.001)

        let expectedFocus = (0.7 * 0.8 + 0.4 * 0.4) / 1.2
        XCTAssertEqual(song.focusScore, expectedFocus, accuracy: 0.001)

        let expectedEnergy = (0.3 * 0.8 + 0.9 * 0.4) / 1.2
        XCTAssertEqual(song.activationScore, expectedEnergy, accuracy: 0.001)

        // Max confidence
        XCTAssertEqual(song.confidenceLevel, 0.8, accuracy: 0.001)
    }

    func test_songAggregates_noConfidentEffects_resetsToDefaults() {
        let song = makeSong()

        // Create an effect with zero confidence
        let _ = makeSongEffect(
            for: song,
            moodLiftScore: 0.9,
            confidenceLevel: 0.0,
            sampleCount: 0
        )

        try? context.save()

        SongEffectHelper.updateSongAggregates(song, in: context)

        XCTAssertEqual(song.moodLiftScore, 0.5, accuracy: 0.001,
                       "Zero-confidence effects should reset moodLiftScore to 0.5")
        XCTAssertEqual(song.calmScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(song.focusScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(song.activationScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(song.confidenceLevel, 0.0, accuracy: 0.001)
    }

    // MARK: - 3. SongEffectHelper.findOrCreateEffect

    func test_findOrCreateEffect_createsNewEffect() {
        let song = makeSong()
        try? context.save()

        let effect = SongEffectHelper.findOrCreateEffect(
            for: song,
            contextType: "workout",
            timeOfDaySlot: "morning",
            in: context
        )

        XCTAssertEqual(effect.contextType, "workout")
        XCTAssertEqual(effect.timeOfDaySlot, "morning")
        XCTAssertEqual(effect.calmScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(effect.focusScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(effect.energyScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(effect.moodLiftScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(effect.sampleCount, 0)
        XCTAssertEqual(effect.confidenceLevel, 0.0, accuracy: 0.001)
        XCTAssertEqual(effect.song, song)
    }

    func test_findOrCreateEffect_findsExisting() {
        let song = makeSong()
        let existing = makeSongEffect(
            for: song,
            contextType: "work",
            calmScore: 0.8,
            moodLiftScore: 0.7
        )
        try? context.save()

        let found = SongEffectHelper.findOrCreateEffect(
            for: song,
            contextType: "work",
            timeOfDaySlot: "afternoon",
            in: context
        )

        XCTAssertEqual(found.objectID, existing.objectID, "Should find existing effect")
        XCTAssertEqual(found.calmScore, 0.8, accuracy: 0.001, "Existing scores should be preserved")
        XCTAssertEqual(found.moodLiftScore, 0.7, accuracy: 0.001, "Existing moodLiftScore should be preserved")
        XCTAssertEqual(found.timeOfDaySlot, "afternoon", "timeOfDaySlot should be updated")
    }

    func test_findOrCreateEffect_differentContextType_createsNew() {
        let song = makeSong()
        let _ = makeSongEffect(for: song, contextType: "work")
        try? context.save()

        let newEffect = SongEffectHelper.findOrCreateEffect(
            for: song,
            contextType: "workout",
            timeOfDaySlot: "morning",
            in: context
        )

        // Should be a new effect since contextType differs
        let effects = song.effects?.allObjects as? [SongEffect] ?? []
        XCTAssertEqual(effects.count, 2, "Should have 2 effects for different context types")
        XCTAssertEqual(newEffect.contextType, "workout")
    }

    // MARK: - 4. SongImpactCalculator — End-to-End

    func test_songImpactCalculator_processesUnprocessedEvents() async throws {
        let song = makeSong()
        let session = makeSession()

        // Create 3 unprocessed events
        let _ = makePlaybackEvent(song: song, session: session, listenPercentage: 0.90, isImpactProcessed: false)
        let _ = makePlaybackEvent(song: song, session: session, listenPercentage: 0.80, isImpactProcessed: false)
        let _ = makePlaybackEvent(song: song, session: session, listenPercentage: 0.70, isImpactProcessed: false)

        try context.save()

        let calculator = SongImpactCalculator(persistence: persistence)
        let processedCount = try await calculator.calculateImpacts()

        XCTAssertEqual(processedCount, 3, "Should process all 3 unprocessed events")
    }

    func test_songImpactCalculator_createsAndUpdatesSongEffects() async throws {
        let song = makeSong()
        let session = makeSession(contextType: "workout", timeOfDaySlot: "morning")

        // Create a full-listen event
        let _ = makePlaybackEvent(
            song: song,
            session: session,
            listenPercentage: 0.95,
            wasSkipped: false,
            isImpactProcessed: false
        )

        try context.save()

        let calculator = SongImpactCalculator(persistence: persistence)
        let _ = try await calculator.calculateImpacts()

        // Refresh song from the view context
        context.refresh(song, mergeChanges: true)

        // The calculator runs on a background context; fetch the SongEffect from our context
        let request = NSFetchRequest<SongEffect>(entityName: "SongEffect")
        request.predicate = NSPredicate(format: "song == %@", song)
        let effects = try context.fetch(request)

        XCTAssertFalse(effects.isEmpty, "SongEffect should have been created")

        if let effect = effects.first {
            XCTAssertEqual(effect.contextType, "workout")
            XCTAssertEqual(effect.sampleCount, 1)
            XCTAssertGreaterThan(effect.confidenceLevel, 0.0, "Confidence should be > 0 after processing")
            // Full listen without biometrics: all scores should shift above 0.5
            // Starting at 0.5, EMA with alpha=0.4 (cold start): new = 0.6*0.5 + 0.4*impact
            // impact > 0.5 for full listen, so effect scores > 0.5
            XCTAssertGreaterThan(effect.moodLiftScore, 0.5,
                                 "moodLiftScore should increase after full listen")
        }
    }

    // MARK: - 5. isImpactProcessed Prevents Double-Counting

    func test_songImpactCalculator_skipsAlreadyProcessedEvents() async throws {
        let song = makeSong()
        let session = makeSession()

        // Create an already-processed event
        let _ = makePlaybackEvent(
            song: song,
            session: session,
            listenPercentage: 0.90,
            isImpactProcessed: true  // Already processed
        )

        try context.save()

        let calculator = SongImpactCalculator(persistence: persistence)
        let processedCount = try await calculator.calculateImpacts()

        XCTAssertEqual(processedCount, 0, "Should skip already-processed events")
    }

    func test_songImpactCalculator_marksEventsAsProcessed() async throws {
        let song = makeSong()
        let session = makeSession()

        let event = makePlaybackEvent(
            song: song,
            session: session,
            listenPercentage: 0.85,
            isImpactProcessed: false
        )

        try context.save()

        let calculator = SongImpactCalculator(persistence: persistence)
        let _ = try await calculator.calculateImpacts()

        // Refresh and check the event
        context.refresh(event, mergeChanges: true)
        XCTAssertTrue(event.isImpactProcessed, "Event should be marked as processed after calculation")
    }

    func test_songImpactCalculator_runTwice_secondRunProcessesZero() async throws {
        let song = makeSong()
        let session = makeSession()

        let _ = makePlaybackEvent(song: song, session: session, listenPercentage: 0.90, isImpactProcessed: false)
        let _ = makePlaybackEvent(song: song, session: session, listenPercentage: 0.80, isImpactProcessed: false)

        try context.save()

        let calculator = SongImpactCalculator(persistence: persistence)

        let firstRunCount = try await calculator.calculateImpacts()
        XCTAssertEqual(firstRunCount, 2, "First run should process 2 events")

        let secondRunCount = try await calculator.calculateImpacts()
        XCTAssertEqual(secondRunCount, 0, "Second run should process 0 events (all marked processed)")
    }

    func test_songImpactCalculator_mixedProcessedAndUnprocessed() async throws {
        let song = makeSong()
        let session = makeSession()

        // 2 already processed, 1 new
        let _ = makePlaybackEvent(song: song, session: session, listenPercentage: 0.90, isImpactProcessed: true)
        let _ = makePlaybackEvent(song: song, session: session, listenPercentage: 0.85, isImpactProcessed: true)
        let _ = makePlaybackEvent(song: song, session: session, listenPercentage: 0.70, isImpactProcessed: false)

        try context.save()

        let calculator = SongImpactCalculator(persistence: persistence)
        let processedCount = try await calculator.calculateImpacts()

        XCTAssertEqual(processedCount, 1, "Should only process the 1 unprocessed event")
    }

    // MARK: - 6. SongImpactCalculator Requires Session

    func test_songImpactCalculator_eventsWithoutSession_notProcessed() async throws {
        let song = makeSong()

        // Event with NO session (nil)
        let _ = makePlaybackEvent(
            song: song,
            session: nil,
            listenPercentage: 0.90,
            isImpactProcessed: false
        )

        try context.save()

        let calculator = SongImpactCalculator(persistence: persistence)
        let processedCount = try await calculator.calculateImpacts()

        XCTAssertEqual(processedCount, 0, "Events without a session should not be processed")
    }

    // MARK: - 7. PlaylistImpactCalculator — End-to-End

    func test_playlistImpactCalculator_aggregatesMoodLiftScore() async throws {
        let playlist = makePlaylist(name: "Chill Vibes")

        let song1 = makeSong(title: "Song 1")
        let song2 = makeSong(title: "Song 2")

        // Add songs to playlist
        playlist.addToSongs(song1)
        playlist.addToSongs(song2)

        // Song 1: high calm, high moodLift
        let _ = makeSongEffect(
            for: song1,
            calmScore: 0.9,
            focusScore: 0.6,
            energyScore: 0.2,
            moodLiftScore: 0.85,
            confidenceLevel: 0.8,
            sampleCount: 15
        )

        // Song 2: moderate everything
        let _ = makeSongEffect(
            for: song2,
            calmScore: 0.5,
            focusScore: 0.5,
            energyScore: 0.5,
            moodLiftScore: 0.5,
            confidenceLevel: 0.6,
            sampleCount: 10
        )

        try context.save()

        let calculator = PlaylistImpactCalculator(persistence: persistence)
        let updatedCount = try await calculator.calculatePlaylistImpacts()

        XCTAssertEqual(updatedCount, 1, "Should update 1 playlist")

        // Refresh the playlist
        context.refresh(playlist, mergeChanges: true)

        // Verify moodLiftScore was aggregated
        // Song 1: songWeight = 0.8, songMoodLift = 0.85, avgConfidence = 0.8
        // Song 2: songWeight = 0.6, songMoodLift = 0.5, avgConfidence = 0.6
        // totalWeight = 0.8 + 0.6 = 1.4
        // weightedMoodLift = 0.85 * 0.8 + 0.5 * 0.6 = 0.68 + 0.30 = 0.98
        // playlist.avgMoodLiftEffect = 0.98 / 1.4 = 0.7
        let expectedMoodLift = (0.85 * 0.8 + 0.5 * 0.6) / (0.8 + 0.6)
        XCTAssertEqual(playlist.avgMoodLiftEffect, expectedMoodLift, accuracy: 0.01,
                       "Playlist avgMoodLiftEffect should be confidence-weighted average")

        // Verify other dimensions
        let expectedCalm = (0.9 * 0.8 + 0.5 * 0.6) / 1.4
        XCTAssertEqual(playlist.avgCalmEffect, expectedCalm, accuracy: 0.01)

        let expectedEnergy = (0.2 * 0.8 + 0.5 * 0.6) / 1.4
        XCTAssertEqual(playlist.avgEnergyEffect, expectedEnergy, accuracy: 0.01)
    }

    func test_playlistImpactCalculator_skipsPlaylistWithNoEffects() async throws {
        let playlist = makePlaylist(name: "Empty Playlist")
        let song = makeSong()
        playlist.addToSongs(song)
        // No SongEffects created for this song

        try context.save()

        let calculator = PlaylistImpactCalculator(persistence: persistence)
        let updatedCount = try await calculator.calculatePlaylistImpacts()

        XCTAssertEqual(updatedCount, 0, "Playlist with no song effects should be skipped")
    }

    func test_playlistImpactCalculator_skipsPlaylistWithNoSongs() async throws {
        let _ = makePlaylist(name: "Songless Playlist")
        // No songs added

        try context.save()

        let calculator = PlaylistImpactCalculator(persistence: persistence)
        let updatedCount = try await calculator.calculatePlaylistImpacts()

        XCTAssertEqual(updatedCount, 0, "Playlist with no songs should be skipped")
    }

    func test_playlistImpactCalculator_contextAssociations_builtFromSessions() async throws {
        let playlist = makePlaylist(name: "Work Playlist")
        let song = makeSong()
        playlist.addToSongs(song)

        let _ = makeSongEffect(for: song, confidenceLevel: 0.5, sampleCount: 5)

        // Link sessions to the playlist
        let session1 = makeSession(contextType: "work")
        let session2 = makeSession(contextType: "work")
        let session3 = makeSession(contextType: "commute")
        playlist.addToSessions(session1)
        playlist.addToSessions(session2)
        playlist.addToSessions(session3)

        try context.save()

        let calculator = PlaylistImpactCalculator(persistence: persistence)
        let _ = try await calculator.calculatePlaylistImpacts()

        context.refresh(playlist, mergeChanges: true)

        // Verify context associations JSON was created
        XCTAssertNotNil(playlist.contextAssociations, "Context associations should be populated")

        if let data = playlist.contextAssociations,
           let associations = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] {
            XCTAssertEqual(associations["work"]?["count"], 2.0)
            XCTAssertEqual(associations["work"]?["frequency"] ?? -1, 2.0 / 3.0, accuracy: 0.01)
            XCTAssertEqual(associations["commute"]?["count"], 1.0)
            XCTAssertEqual(associations["commute"]?["frequency"] ?? -1, 1.0 / 3.0, accuracy: 0.01)
        } else {
            XCTFail("Failed to decode context associations JSON")
        }
    }

    // MARK: - 8. Playlist Effect Confidence Calculation

    func test_playlistImpactCalculator_effectConfidence_scalesByCoverage() async throws {
        let playlist = makePlaylist(name: "Partial Coverage")

        // 3 songs, but only 1 has effects
        let song1 = makeSong(title: "With Effects")
        let song2 = makeSong(title: "No Effects 1")
        let song3 = makeSong(title: "No Effects 2")
        playlist.addToSongs(song1)
        playlist.addToSongs(song2)
        playlist.addToSongs(song3)

        let _ = makeSongEffect(
            for: song1,
            confidenceLevel: 0.9,
            sampleCount: 20
        )

        try context.save()

        let calculator = PlaylistImpactCalculator(persistence: persistence)
        let _ = try await calculator.calculatePlaylistImpacts()

        context.refresh(playlist, mergeChanges: true)

        // coverage = 1/3 = 0.333
        // avgWeight = 0.9 / 1 = 0.9
        // effectConfidence = 0.9 * 0.333 = 0.3
        let expectedConfidence = 0.9 * (1.0 / 3.0)
        XCTAssertEqual(playlist.effectConfidence, expectedConfidence, accuracy: 0.01,
                       "Effect confidence should scale by song coverage ratio")
    }

    // MARK: - 9. Full Pipeline: Event → SongEffect → Song Aggregates → Playlist Aggregates

    func test_fullPipeline_eventToPlaylistAggregates() async throws {
        // Setup: Playlist → Song → PlaybackEvents (with session)
        let playlist = makePlaylist(name: "Full Pipeline")
        let song = makeSong(title: "Pipeline Song")
        playlist.addToSongs(song)

        let session = makeSession(contextType: "work")
        playlist.addToSessions(session)

        // Create multiple events to build up effects
        for i in 0..<5 {
            let listenPct = 0.80 + Double(i) * 0.04  // 0.80, 0.84, 0.88, 0.92, 0.96
            let _ = makePlaybackEvent(
                song: song,
                session: session,
                listenPercentage: listenPct,
                wasSkipped: false,
                isImpactProcessed: false
            )
        }

        try context.save()

        // Step 1: Run SongImpactCalculator
        let songCalc = SongImpactCalculator(persistence: persistence)
        let processedCount = try await songCalc.calculateImpacts()
        XCTAssertEqual(processedCount, 5, "Should process all 5 events")

        // Step 2: Run PlaylistImpactCalculator
        let playlistCalc = PlaylistImpactCalculator(persistence: persistence)
        let updatedCount = try await playlistCalc.calculatePlaylistImpacts()
        XCTAssertEqual(updatedCount, 1, "Should update 1 playlist")

        // Refresh entities
        context.refresh(song, mergeChanges: true)
        context.refresh(playlist, mergeChanges: true)

        // Verify Song aggregates were updated
        // After 5 full listens, moodLiftScore should be above neutral
        XCTAssertGreaterThan(song.moodLiftScore, 0.5,
                             "Song moodLiftScore should be above neutral after full listens")
        XCTAssertGreaterThan(song.confidenceLevel, 0.0,
                             "Song confidence should be > 0 after 5 events")

        // Verify Playlist aggregates
        XCTAssertGreaterThan(playlist.avgMoodLiftEffect, 0.5,
                             "Playlist avgMoodLiftEffect should be above neutral")
        XCTAssertGreaterThan(playlist.effectConfidence, 0.0,
                             "Playlist confidence should be > 0")
    }

    // MARK: - 10. EMA Two-Tier Learning Rate

    func test_ema_coldStartLearningRate_usedForFirstFiveSamples() async throws {
        let song = makeSong()
        let session = makeSession()

        // Create a single event
        let _ = makePlaybackEvent(
            song: song,
            session: session,
            listenPercentage: 0.95,
            isImpactProcessed: false
        )

        try context.save()

        let calculator = SongImpactCalculator(persistence: persistence)
        let _ = try await calculator.calculateImpacts()

        // Fetch the created SongEffect
        let request = NSFetchRequest<SongEffect>(entityName: "SongEffect")
        request.predicate = NSPredicate(format: "song == %@", song)
        let effects = try context.fetch(request)

        guard let effect = effects.first else {
            XCTFail("SongEffect should exist after processing")
            return
        }

        // After 1 sample with cold-start alpha=0.4:
        // newScore = (1 - 0.4) * 0.5 + 0.4 * impact
        // For 95% listen without biometrics:
        // impact.moodLift = clamp(0.5 + (0.95-0.5)*0.2*1.5) = clamp(0.5 + 0.135) = 0.635
        // newMoodLift = 0.6 * 0.5 + 0.4 * 0.635 = 0.30 + 0.254 = 0.554
        XCTAssertEqual(effect.sampleCount, 1)
        XCTAssertGreaterThan(effect.moodLiftScore, 0.5,
                             "moodLiftScore should increase from neutral after full listen")
        XCTAssertLessThan(effect.moodLiftScore, 0.7,
                          "With alpha=0.4, one sample shouldn't move score too far")
    }

    // MARK: - 11. Familiarity Update

    func test_songImpactCalculator_updatesFamiliarity() async throws {
        let song = makeSong()
        song.totalPlayCount = 5
        let session = makeSession()

        let _ = makePlaybackEvent(song: song, session: session, isImpactProcessed: false)

        try context.save()

        let calculator = SongImpactCalculator(persistence: persistence)
        let _ = try await calculator.calculateImpacts()

        context.refresh(song, mergeChanges: true)

        // familiarity = min(1.0, totalPlayCount / 10.0) = min(1.0, 5/10) = 0.5
        XCTAssertEqual(song.familiarityScore, 0.5, accuracy: 0.001,
                       "Familiarity should be totalPlayCount / 10.0")
    }

    // MARK: - 12. Multiple Songs in Playlist

    func test_playlistImpactCalculator_multipleSongs_weightedCorrectly() async throws {
        let playlist = makePlaylist(name: "Multi-Song")

        let song1 = makeSong(title: "High Confidence Song")
        let song2 = makeSong(title: "Low Confidence Song")
        playlist.addToSongs(song1)
        playlist.addToSongs(song2)

        // Song 1: high confidence, high moodLift
        let _ = makeSongEffect(
            for: song1,
            moodLiftScore: 0.9,
            confidenceLevel: 1.0,
            sampleCount: 25
        )

        // Song 2: low confidence, low moodLift
        let _ = makeSongEffect(
            for: song2,
            moodLiftScore: 0.2,
            confidenceLevel: 0.1,
            sampleCount: 2
        )

        try context.save()

        let calculator = PlaylistImpactCalculator(persistence: persistence)
        let _ = try await calculator.calculatePlaylistImpacts()

        context.refresh(playlist, mergeChanges: true)

        // The high-confidence song should dominate the weighted average
        // Song1: avgConf=1.0, songMoodLift=0.9 → weighted contribution = 0.9*1.0 = 0.9
        // Song2: avgConf=0.1, songMoodLift=0.2 → weighted contribution = 0.2*0.1 = 0.02
        // totalWeight = 1.1
        // avgMoodLift = (0.9 + 0.02) / 1.1 = 0.836
        let expected = (0.9 * 1.0 + 0.2 * 0.1) / (1.0 + 0.1)
        XCTAssertEqual(playlist.avgMoodLiftEffect, expected, accuracy: 0.02,
                       "High-confidence song should dominate playlist average")
        XCTAssertGreaterThan(playlist.avgMoodLiftEffect, 0.7,
                             "Result should be close to high-confidence song's score")
    }
}
